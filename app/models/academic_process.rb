# == Schema Information
#
# Table name: academic_processes
#
#  id                          :bigint           not null, primary key
#  active                      :boolean          default(FALSE), not null
#  enroll                      :boolean          default(FALSE), not null
#  max_credits                 :integer
#  max_subjects                :integer
#  modality                    :integer          default("Semestral"), not null
#  name                        :string
#  payments_active             :boolean          default(FALSE), not null
#  post_qualification          :boolean          default(FALSE), not null
#  registration_amount         :float            default(0.0)
#  registration_amount_new     :float            default(0.0)
#  registration_amount_restart :float            default(0.0)
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  period_id                   :bigint           not null
#  process_before_id           :bigint
#  school_id                   :bigint           not null
#
# Indexes
#
#  index_academic_processes_on_period_id          (period_id)
#  index_academic_processes_on_process_before_id  (process_before_id)
#  index_academic_processes_on_school_id          (school_id)
#
# Foreign Keys
#
#  fk_rails_...  (period_id => periods.id)
#  fk_rails_...  (process_before_id => academic_processes.id)
#  fk_rails_...  (school_id => schools.id)
#
class AcademicProcess < ApplicationRecord
  include Totalizable
  # include Schoolizable
  # HISTORY:
  has_paper_trail on: [:create, :destroy, :update]

  has_rich_text :enroll_instructions

  before_create :paper_trail_create
  before_destroy :paper_trail_destroy
  before_update :paper_trail_update

  # ASSOCIATIONS:
  #belongs_to:
  belongs_to :school
  belongs_to :period
  has_one :period_type, through: :period

  belongs_to :process_before, class_name: 'AcademicProcess', optional: true, dependent: :delete

  #has_many:
  has_many :enrollment_days, dependent: :destroy
  has_many :enroll_academic_processes, dependent: :destroy
  has_many :grades, through: :enroll_academic_processes
  has_many :students, through: :grades
  has_many :users, through: :students
  has_many :courses, dependent: :destroy
  has_many :sections, through: :courses
  has_many :schedules, through: :sections
  has_many :academic_records, through: :sections
  has_many :subjects, through: :courses

  # ENUMERIZE:
  enum modality: [:Semestral, :Anual, :Intensivo, :Unico]

  #VALIDATIONS:
  validates :school, presence: true
  validates :period, presence: true
  validates :modality, presence: true
  validates :max_credits, presence: true
  validates :max_subjects, presence: true

  validates_uniqueness_of :school, scope: [:period, :modality], message: 'Proceso academico ya creado', field_name: false

  # SCOPE:
  default_scope { order(name: :desc) }

  scope :actives, -> {where(active: true)}
  scope :enrolls, -> {where(enroll: true)}
  scope :post_qualifications, -> {where(post_qualification: true)}
  scope :payments_actives, -> {where(payments_active: true)}
  scope :without_enroll_academic_processes, -> {left_joins(:enroll_academic_processes).where('enroll_academic_processes.academic_process_id': nil)}
  # Atention: To be commented by not use
  scope :sort_by_period, -> {unscoped.joins(:period).order('periods.year desc').second}
  # CALLBACKS:
  # before_validation :set_numbers_default
  before_save :set_name

  # def set_numbers_default
    
  #   max_credits ||= 48
  #   max_subjects ||= 5

  #   p "max_credits: #{max_credits}"
  #   p "max_subjects: #{max_subjects}"
  # end

  def name_without_school
    name.split(" | ").last
  end
  def conv_type
    "#{I18n.t("activerecord.scopes.academic_process."+self.modality)}#{self.period.period_type.code.upcase}"
  end

  def self.letter_to_modality letter
    I18n.t("activerecord.scopes.academic_process."+letter)
  end
  
  def active_or_enroll?
    (active? or enroll?)
  end

  def invalid_grades_to_csv

    grades_others = Grade.enrolled_in_academic_process(self.process_before_id).others_permanence_invalid_to_enroll

    CSV.generate do |csv|
      csv << ['Est. Permanencia', 'Cédula', 'Apellido y Nombre', 'Eficiencia', 'Promedio', 'Ponderado']
      grades_others.each do |grade|
        user = grade.user
    
        # iep = grade.enroll_academic_processes.of_academic_process(self.id).first
        # enroll_status = (iep&.enroll_status) ? iep.enroll_status&.titleize : 'Sin Inscripción'
        csv << [grade.current_permanence_status&.titleize, user.ci, user.reverse_name, grade.efficiency, grade.simple_average, grade.weighted_average]
      end
    end
  end


  # FUNCTIONS:

  
  def last_2_academic_process_ids
    if before = process_before
      aux = [before.id]
      aux << before.process_before_id if !Anual?
    end
  end

  def last_2_academic_processes
    AcademicProcess.where(id: last_2_academic_process_ids)
  end

  # def self.translate_modality letter
  #   case letter
  #   when 'I'
  #     :Intensivo
  #   when 'U'
  #     :Unico
  #   when 'S'
  #     :Semestral
  #   when 'C'
  #     :Consecutivo
  #   else
  #     :Anual
  #   end
  # end
  def header_level
    (self.Anual?) ? 'Año' : 'Sem'
  end

	def process_name_revert
		"#{self.modality[0]&.upcase}#{period&.name_revert}" 
	end  

  def process_name
    "#{period&.name}#{self.modality[0]&.upcase}"
  end
  def period_desc_and_modality
    "#{period&.name}#{self.modality[0]&.upcase}"
  end
  
  def subject_active_for_this? subject_id
    subjects.ids.include?(subject_id)
  end

  def period_name
    period.name if period
  end

  def exame_type
    "#{period.period_type.name.upcase} #{modality.upcase}" if (period&.period_type and modality)
  end

  def default_value_by_import
    max_credits = 24
    max_subject = 5
    modality = :semestral
  end

  def short_desc
    "#{self.school.short_name} #{self.period_desc_and_modality}" if (self.school and self.period)
  end
  def description
    "#{self.school.name} #{self.process_name}" if (self.school and self.period)
  end

  def get_name
    "#{self.school.code} | #{self.period_desc_and_modality}" if (self.school and self.period)
  end


  def total_enroll_academic_processes
    self.enroll_academic_processes.count
  end

  def link_to_massive_confirmation
    "<a href='/academic_processes/#{id}/massive_confirmation' data-bs-toggle='tooltip' title='Confirmar preinscritos y reservados con reporte de pago' data-confirm='Está acción confirmará #{self.enroll_academic_processes.not_confirmado.total_with_payment_report} estudiantes (preinscritos o reservados) con reporte de pago. ¿Está completamente seguro?' class='label bg-info'><i class= 'fa-regular fa-list-check'></i></a>".html_safe
  end

  def link_to_massive_actas_generation
    # simple_toggle href, value, title_tooltip, color_type, icon, onclick_action = nil
    "<a href='/academic_processes/#{id}/massive_actas_generation' data-bs-toggle='tooltip' title='Generar todas las actas de las secciones calificadas (#{sections.qualified.count})' data-confirm='Está acción generará todos las actas de las secciones calificadas. ¿Está completamente seguro?' class='label bg-info' target='_blank' rel='noopener noreferrer'><i class='fa-regular fa-list'></i></a>".html_safe
  end 

  def label_total_enrolls_by_status(linked=false)
    # label_status_with_tooptip
    total = []    
    link = con_reportes = sin_reportes = ''
    if linked
      link = "/admin/enroll_academic_process?query=#{process_name}"
      con_reportes = "#{link}&model_name=enroll_academic_process&scope=con_reporte_de_pago"
      sin_reportes = "#{link}&model_name=enroll_academic_process&scope=sin_reporte_de_pago"
    end
    
    total << ApplicationController.helpers.label_link_with_tooltip(link, 'bg-secondary me-1', self.enroll_academic_processes.count, 'Total')
    total << ApplicationController.helpers.label_link_with_tooltip(con_reportes, 'bg-success me-1', self.enroll_academic_processes.total_with_payment_report, 'Con Reportes de Pago')
    total << ApplicationController.helpers.label_link_with_tooltip(sin_reportes, 'bg-warning me-1', self.enroll_academic_processes.total_without_payment_report, 'Sin Reportes de Pago')

    EnrollAcademicProcess.enroll_statuses.map do |k,v|
      total_aux = self.enroll_academic_processes.where(enroll_status: v).count 
      tipo = EnrollAcademicProcess.type_label_by_enroll k
      url = linked ? link+"&scope=#{k}" : ""
      total << ApplicationController.helpers.label_link_with_tooltip(url, "bg-#{tipo} me-1", total_aux, k&.pluralize&.titleize)
    end
    return total.join
    
  end
  
  def btn_total_enrolls_by_status 
    total = []

    link = "/admin/enroll_academic_process?f[school][99071][o]=like&f[school][99071][v]=#{school&.short_name}&f[academic_process][99124][o]=like&f[academic_process][99124][v]=#{process_name}"
    total << ApplicationController.helpers.label_link_with_tooptip(link, 'bg-secondary', self.enroll_academic_processes.count, 'Total')

    total << ApplicationController.helpers.label_link_with_tooptip("#{link}&model_name=enroll_academic_process&scope=con_reporte_de_pago", 'bg-success', self.enroll_academic_processes.total_with_payment_report, 'Con Reportes de Pago')    
    total << ApplicationController.helpers.label_link_with_tooptip("#{link}&model_name=enroll_academic_process&scope=sin_reporte_de_pago", 'bg-warning', self.enroll_academic_processes.total_without_payment_report, 'Sin Reportes de Pago')    


    

    EnrollAcademicProcess.enroll_statuses.map do |k,v|
      total_aux = self.enroll_academic_processes.where(enroll_status: v).count 
      tipo = EnrollAcademicProcess.type_label_by_enroll k
      url = link+"&scope=#{k}"
      total << ApplicationController.helpers.label_link_with_tooptip(url, "bg-#{tipo}", total_aux, k&.pluralize&.titleize)
    end
    return total.join
    
  end


  def label_total_sections
    total = []
    total << ApplicationController.helpers.label_status_with_tooltip('bg-info', total_sections, 'Total')
    total << ApplicationController.helpers.label_status_with_tooltip('bg-success', total_sections_qualified, 'Calificadas')
    
    total << ApplicationController.helpers.label_status_with_tooltip('bg-danger', total_sections_without_teacher_assigned, 'Sin Profesor Asignado')

    return total
  end

  def total_academic_records
    self.academic_records.count
  end

  def total_sections
    self.sections.count
  end

  def total_sections_qualified
    self.sections.qualified.count
  end

  def total_sections_without_teacher_assigned
    self.sections.without_teacher_assigned.count
  end

  def enrolling?
    enroll?
  end

  def update_grades_enrollment_day (to_enroll_academic_processes, final_lap, appointment_time, duration_slot_time)

    total_updated = 0
    entities = self.ready_to_enrollment_day to_enroll_academic_processes

    entities[0..final_lap].each do |ent| 
      grade = to_enroll_academic_processes ? ent.grade : ent
      total_updated += 1 if grade.update(appointment_time: appointment_time, duration_slot_time: duration_slot_time)
    end
    return total_updated
  end

  def ready_to_enrollment_day to_enroll_academic_processes
    to_enroll_academic_processes ? enrolleds_ready_to_enrollment_day : grades_ready_to_enrollment_day
  end

  def grades_ready_to_enrollment_day
    self.school.grades.valid_to_enrolls(self.id,self.process_before.id).sort_by_numbers.uniq if process_before
  end

  def enrolleds_ready_to_enrollment_day
    self.process_before&.enroll_academic_processes.valid_to_enroll_in.sort_by_numbers_of_this_process
  end

  def update_enroll_academic_processes_permanence_status
      self.enroll_academic_processes.each{|eap| eap.update(permanence_status: eap.get_regulation) if eap.finished?}
  end

  def update_enroll_academic_processes_with_grade
      self.enroll_academic_processes.each do |eap| 
        eap.update(permanence_status: eap.get_regulation)
        eap.grade.update(current_permanence_status: eap.get_regulation)
      end
  end

  def self.icon_entity
    'fa-solid fa-calendar'
  end

  def label_process value
    if value
      tipo = 'success'
      fa = 'check'
    else
      tipo = 'danger'
      fa = 'times'
    end
    "<span class='badge bg-#{tipo}'><span class='fas fa-#{fa}'></span></span>"
  end

  def label_active
    label_process active?
  end
  
  def label_enroll
    label_process enroll?
  end 

  def label_post_q
    label_process post_qualification?
  end 
  
  def label_payment_actives
    label_process payments_active?
  end

  rails_admin do
    navigation_label 'Config Específica'
    navigation_icon 'fa-solid fa-calendar'
    weight -3
    list do
      items_per_page 12
      checkboxes false
      sort_by 'periods.name'
      filters [:school, :period]

      field :school do
        sticky true
        column_width 150

        pretty_value do
          value.short_name
        end        
        
      end
      
      fields :period do
        sticky true
        label 'Período'
        column_width 100
        pretty_value do
          # value.name
          bindings[:object]&.process_name
        end
      end

      field :process_before do
        column_width 80
        pretty_value do
          bindings[:object]&.process_before&.process_name
        end
      end

      # EVALUAR SI VALE LA PENA INCLUIRLA AQUÍ
      # field :active_enroll do
      #   label 'Inscripción'
      #   pretty_value do
      #     current_user = bindings[:view]._current_user
      #     bindings[:view].render(partial: "/academic_processes/enroll_state", locals: {academic_process: bindings[:object]})
      #   end
      # end
      field :enroll do
        label 'Inscripción'
        # pretty_value do
        #   "#{bindings[:object].label_active} p".html_safe
        # end
        pretty_value do
          current_user = bindings[:view]._current_user
          if current_user&.admin&.authorized_manage? 'AcademicProcess'
            bindings[:view].render(partial: "/academic_processes/active_process", locals: {academic_process: bindings[:object], mode: 'enroll'})
          else
            bindings[:object].label_enroll&.html_safe
          end
        end
      end

      field :payments_active do
        label 'Pagos'
        pretty_value do
          current_user = bindings[:view]._current_user
          if current_user&.admin&.authorized_manage? 'AcademicProcess'
            bindings[:view].render(partial: "/academic_processes/active_process", locals: {academic_process: bindings[:object], mode: 'payments_active'})
          else
            bindings[:object].label_payment_actives&.html_safe
          end
        end
      end

      field :active do
        label 'Activo'
        pretty_value do
          current_user = bindings[:view]._current_user
          if current_user&.admin&.authorized_manage? 'AcademicProcess'
            bindings[:view].render(partial: "/academic_processes/active_process", locals: {academic_process: bindings[:object], mode: 'active'})
          else
            bindings[:object].label_active&.html_safe
          end
        end
      end

      field :post_qualification do
        label 'Cal. Posterior'

        pretty_value do
          if GeneralSetup.enabled_post_qualification?
            current_user = bindings[:view]._current_user
            if current_user&.admin&.authorized_manage? 'AcademicProcess'
              bindings[:view].render(partial: "/academic_processes/active_process", locals: {academic_process: bindings[:object], mode: 'post_qualification'})
            else
              bindings[:object].label_post_q&.html_safe
            end
          else
            nil
          end
        end

      end

      field :total_sections do

        column_width 180
        label 'Secciones'
        pretty_value do 
          user = bindings[:view]._current_user
          if (user&.admin&.authorized_read? 'Section')

            %{<a href='/admin/section?f%5Bacademic_process%5D%5B83223%5D%5Bo%5D=like&f%5Bacademic_process%5D%5B83223%5D%5Bv%5D=#{bindings[:object].process_name}&f%5Bschool%5D%5B96616%5D%5Bo%5D=like&f%5Bschool%5D%5B96616%5D%5Bv%5D=#{bindings[:object].school.short_name}' data-bs-toggle = 'tooltip', title='Total Secciones'><span class='text-dark badge bg-info'>#{value} en #{bindings[:object].courses.count} Cursos</span></a> #{bindings[:object].link_to_massive_actas_generation if bindings[:object].sections.qualified.any?}}.html_safe
          else
            %{<span class='text-dark badge bg-info'>#{value}</span>}.html_safe
          end
        end
      end

      field :numbers_enrolled do
        column_width 300
        label 'Estudiantes'
        formatted_value do
          bindings[:view].render(partial: '/academic_processes/numbers_labels', locals: {ap: bindings[:object], authorized: (bindings[:view]._current_user&.admin&.authorized_read? 'EnrollAcademicProcess')})
        end
      end
      
      field :total_academic_records do
        column_width 100
        label 'Inscritos por Asignatura'
        pretty_value do
          user = bindings[:view]._current_user
          if (user and user.admin and user.admin.authorized_read? 'AcademicRecord')

            link = "/admin/academic_record?f[school][03085][o]=like&f[school][03085][v]=#{bindings[:object].school&.short_name}&f[academic_process][03111][o]=like&f[academic_process][03111][v]=#{bindings[:object].process_name}"
            a = %{<a href=#{link} data-bs-toggle='tooltip' title='Total Inscripciones En Asignaturas'><span class='badge bg-info'>#{value}</span></a>}.html_safe
            "#{a} #{ApplicationController.helpers.link_academic_records_csv bindings[:object]}".html_safe
          else
            %{<span class='badge bg-info'>#{value}</span>}.html_safe
          end
        end
      end

      field :enroll_academic_processes do
        column_width 100
        label 'Inscritos por Período'
        pretty_value do
          user = bindings[:view]._current_user
          total = bindings[:object].enroll_academic_processes.count
          if (user&.admin&.authorized_read? 'EnrollAcademicProcess')
            link = "/admin/enroll_academic_process?f[school][99071][o]=like&f[school][99071][v]=#{bindings[:object].school&.short_name}&f[academic_process][99124][o]=like&f[academic_process][99124][v]=#{bindings[:object].process_name}"
            a = %{<a href=#{link} data-bs-toggle='tooltip' title='Total Inscripciones En Periodo'><span class='badge bg-info'>#{total}</span></a>}.html_safe
            "#{a} #{ApplicationController.helpers.link_enroll_academic_process_csv bindings[:object]}".html_safe
          else
            %{<span class='badge bg-info'>#{value}</span>}.html_safe
          end
        end
      end      

    end

    edit do
      # group :default do
      #   hide
      # end      
      field :school do
        inline_edit false
        inline_add false
        partial 'school/custom_school_id_field'
      end
      field :period do
        inline_edit false
      end
      field :modality
      field :description do
        visible false
      end
      field :active do
        visible false
      end
      field :enroll do
        visible false
      end    
      field :process_before do
        inline_edit false
        inline_add false
        help 'Atención: Aún cuando este campo no es obligatorio y puede ser omitido es muy importante para las Citas Horarias e Inscripciones'

        partial 'academic_process/custom_academic_process_id_field'
        
      end

      field :max_credits do
        label 'Máximo de créditos permitidos a inscribir'
      end
      field :max_subjects do
        label 'Máximo de asignaturas permitidas a inscribir'
      end

      field :enroll_instructions do
        help 'Si desea agregar imágenes tome en cuenta el tamaño de misma y su ajuste a la pantalla dónde se desplegará'
      end

      fields :registration_amount, :registration_amount_new, :registration_amount_restart
    end

    update do
      # group :default do
      #   hide
      # end
      field :description do
        read_only true
      end
      field :active
      field :enroll
      field :school do
        visible false
      end
      field :period do
        visible false
        pretty_value do
          value.name
        end
      end
      field :modality do
        visible false
      end
      
      field :process_before do
        inline_edit false
        inline_add false
        help 'Atención: Aún cuando este campo no es obligatorio y puede ser omitido es indispensable para las generación de Citas Horarias, Programaciones e Inscripciones'

        partial 'academic_process/custom_academic_process_id_field'
        
      end

      field :max_credits do
        label 'Máximo de créditos permitidos a inscribir'
      end
      field :max_subjects do
        label 'Máximo de asignaturas permitidas a inscribir'
      end

      field :enroll_instructions do
        help 'Si desea agregar imágenes tome en cuenta el tamaño de misma y su ajuste a la pantalla dónde se desplegará'
      end

      field :registration_amount do
        # pretty_value do
        #   bindings[:view].content_tag()
        # end
      end
    end    

    show do
      field :name do
        label 'Descripción'
        pretty_value do
          bindings[:view].render(partial: "/academic_processes/desc_table", locals: {academic_process: bindings[:object]})
        end
      end

      # EVALUAR SI INCLUIR
      field :active_enroll do
        label 'Inscripción'
        formatted_value do
          current_user = bindings[:view]._current_user
          bindings[:view].render(partial: "/academic_processes/enroll_state", locals: {academic_process: bindings[:object]})
        end
      end

      field :enroll_instructions

      # field :courses do
      #   visible do
      #     user = bindings[:view]._current_user
      #     (user and user.admin and user.admin.authorized_manage? 'AcademicProcess')
      #   end
      #   label "Programación"
      #   pretty_value do
      #     bindings[:view].render(partial: "/academic_processes/programation", locals: {academic_process: bindings[:object]})
      #   end
      # end

      # field :enrollment_days do
      #   visible do
      #     user = bindings[:view]._current_user
      #     (user and user.admin and user.admin.authorized_manage? 'AcademicProcess')
      #   end
      #   pretty_value do
      #     if bindings[:object].process_before
      #       enrollment_days = bindings[:object].enrollment_days
      #       grades_without_appointment = bindings[:object].readys_to_enrollment_day

      #       bindings[:view].render(partial: "/enrollment_days/index", locals: {enrollment_days: enrollment_days, grades_without_appointment: grades_without_appointment, academic_process: bindings[:object]})

      #     else
      #       bindings[:view].content_tag(:p, 'Sin proceso academico anterio vinculado. Para habilitar el sistema de Cita Horaria en este proceso académico, por favor edítelo y agregue un proceso anteriór', {class: 'alert alert-warning'})
      #     end
      #   end

      # end
    end

    export do
      fields :school, :period, :modality, :subjects, :max_credits, :max_subjects
    end
  end

  # after_initialize do
  #   if new_record?
  #     self.school_id ||= School.first.id
  #   end
  # end

  def redundant_subjects
    subj = self.courses.group(:subject_id).having('count(*) > 1').count
    sub_ids = subj.keys
    self.subjects.where(id: sub_ids) 
  end

  def remove_redundant_courses
    aux = redundant_subjects
    if aux.any?
      aux.each{|su| su.remove_redundant_courses_of self.id}
    else
      '            Sin cursos Redundates        '.center(500, '-')
    end
  end

  private

    def set_name
      self.name = self.get_name
    end

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
      self.paper_trail_event = "¡Proceso Académico eliminado!"
    end


end
