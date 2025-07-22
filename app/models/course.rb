# == Schema Information
#
# Table name: courses
#
#  id                  :bigint           not null, primary key
#  name                :string
#  offer               :boolean          default(TRUE)
#  offer_as_pci        :boolean
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  academic_process_id :bigint           not null
#  subject_id          :bigint           not null
#
# Indexes
#
#  index_courses_on_academic_process_id  (academic_process_id)
#  index_courses_on_subject_id           (subject_id)
#
# Foreign Keys
#
#  fk_rails_...  (academic_process_id => academic_processes.id)
#  fk_rails_...  (subject_id => subjects.id)
#
class Course < ApplicationRecord
  include Totalizable
  # Course.all.map{|ap| ap.update(name: 'x')}  
  # HISTORY:

  attr_accessor :session_academic_process_id

	has_paper_trail on: [:create, :destroy, :update]

	before_create :paper_trail_create
	before_destroy :paper_trail_destroy
	before_update :paper_trail_update

  # ASSOCIATIONS:
  # belongs_to
  belongs_to :academic_process
  has_one :period, through: :academic_process
  has_one :school, through: :academic_process
  belongs_to :subject
  has_one :area, through: :subject
  
  # has_many
  has_many :sections, dependent: :destroy
  has_many :academic_records, through: :sections

  #VALIDATIONS:
  validates :subject, presence: true
  validates :academic_process, presence: true

  validates_uniqueness_of :subject_id, scope: [:academic_process_id], message: 'Ya existe la asignatura para el proceso académico.', field_name: false

  # SCOPE
  scope :of_academic_process, ->(academic_process_id){where(academic_process_id: academic_process_id)}
  scope :pcis, -> {where(offer_as_pci: true)}
  scope :order_by_subject_ordinal, -> {joins(:subject).order('subjects.ordinal': :asc)}
  scope :order_by_subject_code, -> {joins(:subject).order('subjects.code': :asc)}
  scope :order_by_subject_ordinal_and_subject_code, -> {joins(:subject).order(['subjects.ordinal': :asc, 'subjects.code': :asc])}

  scope :offers, -> {where(offer: true)}
  
  scope :custom_search, -> (keyword) {joins(:period, :subject).where("subjects.name ILIKE '%#{keyword}%' OR subjects.code ILIKE '%#{keyword}%' OR periods.name ILIKE '%#{keyword}%'") }
  # default_scope {of_academic_process(@academic_process.id)}

  # ORIGINAL CON LEFT JOIN
  # scope :without_sections, -> {joins("LEFT JOIN sections s ON s.course_id = courses.id").where(s: {course_id: nil})}
  
  # OPTIMO CON LEFT OUTER JOIN
  scope :without_sections, -> {left_joins(:sections).where('sections.course_id': nil)}


  # CALLBACKS:
  before_save :set_name

  def get_name
    "#{self.academic_process.name}-#{self.subject.desc}" if self.period and self.school and self.subject
  end

  def qualifications_average
    if total_academic_records > 0
      values = academic_records.joins(:qualifications).sum('qualifications.value')
      (values.to_f/total_academic_records.to_f).round(2)
    end
  end

  def total_sections
    sections.count
  end

  def subject_desc
    self.subject.description_code
  end

  def subject_desc_with_pci
    if offer_as_pci
      self.subject.description_code_with_school
    else
      self.subject.description_code
    end
  end

  def label_pci_yes_or_not
    aux = offer_as_pci ? ['Sí', 'success'] : ['No', 'Secondary']
    "<span class='badge bg-#{aux[1]}'>#{aux[0]}</span>".html_safe
  end

  def label_pci
    aux = offer_as_pci ? ['PCI', 'success'] : ['No', 'Secondary']
    "<span class='badge bg-#{aux[1]}'>#{aux[0]}</span>".html_safe
  end

  def curso_name
    "Curso #{self.name}"
  end

  rails_admin do
    # visible false

    navigation_label 'Config Específica'
    navigation_icon 'fa-solid fa-shapes'
    weight -2

    object_label_method do
      :curso_name
    end


    list do
      sort_by ['courses.name']
      search_by :custom_search
      checkboxes false
      # Las opciones seteables para `list` en RailsAdmin incluyen, entre otras:
      # - items_per_page: para definir la cantidad de elementos por página.
      # - sort_by: para definir el campo o los campos por los cuales ordenar.
      # - sort_reverse: para invertir el orden de la lista.
      # - filters: para definir los filtros disponibles.
      # - search_by: para definir los campos de búsqueda personalizada.
      # - checkboxes: para mostrar o no los checkboxes de selección múltiple.
      # - scopes: para agregar scopes personalizados a la lista.
      # - field: para definir los campos que se mostrarán y sus opciones.

      # - group: para agrupar campos en la vista de lista.

      # Agregar el campo school solo si el usuario actual tiene más de una escuela autorizada
      field :school do
        sticky true
        visible do
          bindings[:view]._current_user&.admin&.schools_auh&.count.to_i > 1
        end
        associated_collection_cache_all true
        associated_collection_scope do
          Proc.new { |scope|
            scope = scope.joins(:school)
            scope = scope.limit(2)
          }
        end
        
        filterable true
        label 'Escuela'
        pretty_value do
          value&.short_name
        end
      end

      field :academic_process do
        sticky true
        queryable true
        label 'Periodo'
        column_width 150
        pretty_value do
          value.process_name
        end
      end
      field :area do
        sticky true
        searchable :name
        sortable :name
      end
      field :subject do
        sticky true
        filterable false
      end
      field :total_sections do
        label "T. Sec"
        pretty_value do
          ApplicationController.helpers.label_status('bg-info', value)
        end
      end

      field :offer

      field :sections do
        column_width '300'
        pretty_value do
          bindings[:object].sections.map{|sec| ApplicationController.helpers.link_to(sec.code, "/admin/section/#{sec.id}")}.to_sentence.html_safe
        end
      end
      field :total_academic_records do
        label 'Ins'
        pretty_value do
          # %{<a href='/admin/academic_record?query=#{bindings[:object].name}'><span class='badge bg-info'>#{ApplicationController.helpers.label_status('bg-info', value)}</span></a>}.html_safe
          ApplicationController.helpers.label_status('bg-info', value)

        end
      end
      field :total_sc do
        label 'SC'
        help 'Sin Calificar'
        pretty_value do
          ApplicationController.helpers.label_status('bg-secondary', value)
        end
      end

      field :total_aprobados do
        label 'A'
        help 'Aprobado'
        pretty_value do
          ApplicationController.helpers.label_status('bg-success', value)
        end
      end
      field :total_aplazados do
        label 'AP'
        pretty_value do
          ApplicationController.helpers.label_status('bg-danger', value)
        end        
      end
      field :total_retirados do
        label 'RT'
        pretty_value do
          ApplicationController.helpers.label_status('bg-secondary', value)
        end        
      end 
      field :total_pi do
        label 'PI'
        pretty_value do
          ApplicationController.helpers.label_status('bg-danger', value)
        end        
      end 
      field :qualifications_average do
        label 'Prom'
        pretty_value do
          ApplicationController.helpers.label_status('bg-info', value)
        end         
      end      
    end

    show do
      fields :academic_process, :subject
      field :sections do
        pretty_value do
          bindings[:view].render(partial: "/sections/index", locals: {sections: bindings[:object].sections, course_id: bindings[:object].id, section_codes: bindings[:object].subject.section_codes})
        end
      end
    end

    edit do
      field :academic_process do
        inline_edit false
        inline_add false
        # partial 'course/custom_academic_process_id_field'
      end

      field :subject do
        inline_edit false
        inline_add false        
      end

    end


    export do
      fields :academic_process, :period, :subject, :area, :offer
      field :total_sections do
        label 'T. Sec'
      end
      field :total_academic_records do
        label 'Ins'
      end
      field :total_sc do
        label 'SC'
      end
      field :total_aprobados do
        label 'A'
        help 'Aprobado'
      end
      field :total_aplazados do
        label 'AP'
      end
      field :total_retirados do
        label 'RT'
      end 
      field :total_pi do
        label 'PI'
      end 
      field :qualifications_average do
        label 'PROM'
      end

    end


  end
  
  private
    def set_name
      self.name = self.get_name
    end

    def paper_trail_update
      changed_fields = self.changes.keys - ['created_at', 'updated_at']
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡#{object} actualizado en #{changed_fields.to_sentence}"
    end  

    def paper_trail_create
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡#{object} creado!"
    end  

    def paper_trail_destroy
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡Curso eliminado!"
    end
end
