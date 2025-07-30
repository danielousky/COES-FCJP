# == Schema Information
#
# Table name: study_plans
#
#  id            :bigint           not null, primary key
#  code          :string
#  levels        :integer          default(10), not null
#  modality      :integer          default("Anual"), not null
#  name          :string
#  structure     :integer          default("por_dependencia"), not null
#  total_credits :integer          default(0)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  school_id     :bigint           not null
#
# Indexes
#
#  index_study_plans_on_school_id  (school_id)
#
# Foreign Keys
#
#  fk_rails_...  (school_id => schools.id)
#
class StudyPlan < ApplicationRecord  
  
  # HISTORY:
  has_paper_trail on: [:create, :destroy, :update]

  before_create :paper_trail_create
  before_destroy :paper_trail_destroy
  before_update :paper_trail_update

  # ASSOCIATIONS:
  belongs_to :school
  # accepts_nested_attributes_for :school

  has_many :grades, dependent: :destroy
  has_many :requirement_by_subject_types, dependent: :destroy
  accepts_nested_attributes_for :requirement_by_subject_types, allow_destroy: true  
  
  has_many :requirement_by_levels, dependent: :destroy
  
  has_many :mentions, dependent: :destroy
  accepts_nested_attributes_for :mentions, allow_destroy: true  

  # VALIDATIONS:
  validates :code, presence: true
  validates :name, presence: true
  validates :modality, presence: true
  validates :levels, presence: true
  # validates :requirement_by_subject_types, presence: true
  validates :school, presence: true
  validates :structure, presence: true

  # ENUMS:
  #AcademicProcess.modalities: {Semestral: 0, Anual: 1, Componente: 4} # Antes: [:Semestral, :Anual, :Intensivo, :Unico, :Componente]
  # enum modality: [:Anual, :Semestral, :Componente]
  enum modality: {Anual: 0, Semestral: 1}
  enum structure: {por_dependencia: 0, por_nivel: 1, sin_restricciones: 2}
  # CALLBACKS:
  before_save :clean_values

  #SCOPE:

  # HOOKS:
  def clean_values
    self.name.delete! '^0-9|^A-Za-z|áÁÄäËëÉéÍÏïíÓóÖöÚúÜüñÑ '
    self.name.strip!
    self.code.delete! '^0-9|^A-Za-z|áÁÄäËëÉéÍÏïíÓóÖöÚúÜüñÑ'
    self.code.strip!
    self.name.upcase!
    self.code.upcase!
  end

  # FUNCTIONS:
  # def initialization
  #   requirement_by_levels
  # end

  def modality_to_tipo
    Anual? ? 'Año' : 'Semestre'
  end

  def modality_to_tipo_short
    Anual? ? 'Año' : 'Sem'
  end  

  def desc_with_school
    "#{school.short_name} - #{name}"
  end

  def code_name
    "(#{code}) #{name}"
  end

  def desc
    "#{school&.short_name} (#{code}) #{name}"
  end

  def label_structure_desc
    ApplicationController.helpers.label_status('bg-info', structure&.titleize)
  end
  # def desc_credits
  #   "(Créditos Requeridos) #{mandatory_credits}"
  # end
  def self.icon_entity
    'fa-solid fa-award'
  end

  rails_admin do
    navigation_label 'Config General'
    navigation_icon 'fa-solid fa-award'
    weight -2

    show do
      fields :school, :code, :modality, :levels, :name, :mentions, :requirement_by_subject_types
    end

    list do
      sort_by :name
      checkboxes false
      field :school do
        sticky true
        pretty_value do
          bindings[:object].school&.short_name
        end
      end
      field :code do
        sticky true
      end
      fields :name, :modality, :levels, :requirement_by_subject_types, :mentions
    end

    export do
      fields :code, :name, :requirement_by_subject_types
    end

    edit do
      field :school do
        inline_add false
        inline_edit false 
        partial 'school/custom_school_id_field'
      end
      field :code do 
        html_attributes do
          {:length => 8, :size => 8, :onInput => "$(this).val($(this).val().toUpperCase().replace(/[^a-zA-Z0-9\u00f1\u00d1 ]/g,''))"}
        end
      end
      field :name do
        html_attributes do
          {:onInput => "$(this).val($(this).val().toUpperCase())"}
        end        
      end
      field :modality do
        partial 'study_plan/custom_modality_field'
        help 'Atención: la opción indicada servirá adicionalemnte para la inscripción de los estudiantes.'        
      end

      fields :levels, :requirement_by_subject_types, :structure#, :mentions

    end
		update do

			field :school do
				inline_edit false
				inline_add false
				read_only true
			end
			field :name
		end    

  end

  private
    def paper_trail_update
      # changed_fields = self.changes.keys - ['created_at', 'updated_at']
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      # self.paper_trail_event = "¡#{object} actualizado en #{changed_fields.to_sentence}"
      self.paper_trail_event = "¡#{object} actualizado!"
    end  

    def paper_trail_create
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡#{object} registrado!"
    end  

    def paper_trail_destroy
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡Plan de Estudio eliminado!"
    end


end
