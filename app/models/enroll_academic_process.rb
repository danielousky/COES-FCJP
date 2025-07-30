# == Schema Information
#
# Table name: enroll_academic_processes
#
#  id                  :bigint           not null, primary key
#  efficiency          :float            default(1.0)
#  enroll_status       :integer
#  permanence_status   :integer
#  simple_average      :float            default(0.0)
#  weighted_average    :float            default(0.0)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  academic_process_id :bigint           not null
#  grade_id            :bigint           not null
#
# Indexes
#
#  index_enroll_academic_processes_on_academic_process_id  (academic_process_id)
#  index_enroll_academic_processes_on_grade_id             (grade_id)
#
# Foreign Keys
#
#  fk_rails_...  (academic_process_id => academic_processes.id)
#  fk_rails_...  (grade_id => grades.id)
#
class EnrollAcademicProcess < ApplicationRecord

  # HISTORY:
  has_paper_trail on: [:create, :destroy, :update]

  before_create :paper_trail_create
  before_destroy :paper_trail_destroy
  before_update :paper_trail_update

  # OJO: Sólo para la migradión:
  # Excluir la siguiente validación y agregar la que viene luego
  after_save :update_current_permanence_status_on_grade
  
  # before_validation :set_enroll_status
  
  # def set_enroll_status
  #   enroll_status = :confirmado
  # end
  
  # ASSOCIATIONS:
  belongs_to :grade
  has_one :student, through: :grade
  has_one :study_plan, through: :grade
  has_one :user, through: :student
  has_one :school, through: :grade
  
  belongs_to :academic_process
  has_one :period, through: :academic_process
  has_many :payment_reports, as: :payable, dependent: :destroy
  has_many :academic_records, dependent: :destroy
  has_many :sections, through: :academic_records
  has_many :timetables, through: :sections
  has_many :timeblocks, through: :timetables  
  has_many :schedules, through: :sections
  has_many :subjects, through: :sections

  # ENUMERIZE:
  # IDEA CON ESTADO DE INSCRIPCIÓN EN GRADE Y ENROLL ACADEMIC PROCESS
  enum enroll_status: [:preinscrito, :reservado, :confirmado]
  enum permanence_status: [:nuevo, :regular, :reincorporado, :articulo3, :articulo6, :articulo7, :intercambio, :desertor, :egresado, :egresado_doble_titulo, :permiso_para_no_cursar, :retiro_total, :por_calificar]  

  # VALIDATIONS:
  validates :grade, presence: true
  validates :academic_process, presence: true
  validates :enroll_status, presence: true

  validates_uniqueness_of :academic_process, scope: [:grade], message: 'Ya inscrito en período', field_name: false
  # validates :permanence_status, presence: true

  # SCOPE:
  scope :todos, -> {where('0 = 0')}

  scope :of_academic_process, -> (academic_process_id) {where(academic_process_id: academic_process_id)}

  # scope :preinscrito_or_reservado, -> (){where(enroll_status: [:preinscrito, :reservado])}

  scope :sort_by_period, -> {joins(period: :period_type).order('periods.year': :desc, 'period_types.name': :desc)}
  
  scope :last_enrolled, -> {sort_by_period.first}

  scope :sort_by_period_reverse, -> {joins(period: :period_type).order('periods.year': :asc, 'period_types.name': :asc)}


  scope :valid_to_enroll_in, -> () {joins(:grade).where("grades.current_permanence_status": [:regular, :reincorporado, :articulo3], "grades.appointment_time": nil)}


  scope :sort_by_numbers_of_this_process, -> () {order(['enroll_academic_processes.efficiency': :desc, 'enroll_academic_processes.simple_average': :desc, 'enroll_academic_processes.weighted_average': :desc])}

  scope :without_academic_records, -> {joins(:academic_records).group(:"enroll_academic_processes.id").having('COUNT(*) = 0').count}

  scope :with_any_academic_records, -> {joins(:academic_records).group(:"enroll_academic_processes.id").having('COUNT(*) > 0').count}

  scope :with_i_academic_records, -> (i){joins(:academic_records).group(:"enroll_academic_processes.id").having('COUNT(*) = ?', i).count}
  
  scope :total_with_i_academic_records, -> (i){(joins(:academic_records).group(:"enroll_academic_processes.id").having('COUNT(*) = ?', i).count).count}

  scope :custom_search, -> (keyword) { joins(:user, :period).where("users.ci ILIKE '%#{keyword}%' OR periods.name ILIKE '%#{keyword}%'") }

  
  scope :with_payment_report, -> {joins(:payment_reports)}
  #Alias
  scope :con_reporte_de_pago, -> {with_payment_report}
  scope :without_payment_report, -> {left_joins(:payment_reports).where('payment_reports.payable_id': nil)}
  scope :sin_reporte_de_pago, -> {without_payment_report}
  
  scope :total_with_payment_report, -> {with_payment_report.count}
  scope :total_without_payment_report, -> {without_payment_report.count}

  scope :student_merito, -> (academic_process_ids) {includes(:user, :grade, :academic_process).where('acamidec_process.ids': academic_process_ids)}
  
  scope :qualfied_complety, -> {joins(:academic_records).where('academic_records.status != 0')}
  def total_retire?
    academic_records.any? and (academic_records.count.eql? academic_records.retirado.count)
  end

  # FUNCTIONS:
  def payment_process
    academic_process
  end


  def resume_payment_reports
    payment_reports.map(&:name)
  end
  def self.header_for_report
    ['#', 'CI', 'NOMBRES', 'APELLIDOS','ESCUELA', 'NIVEL', 'PERIODO','ESTADO INSCRIP','ESTADO PERMANENCIA','REPORTE PAGO']
  end

  def values_for_report
    # ['#', 'CI', 'NOMBRES', 'APELLIDOS','ESCUELA','PERIODO','ESTADO INSCRIP','ESTADO PERMANENCIA','REPORTE PAGO']
    user_aux = user
    [user_aux.ci, user_aux.first_name, user_aux.last_name, school.name, academic_process.process_name, enroll_status&.titleize, permanence_status&.titleize, resume_payment_reports]
  end
  def overlapped? timetable
    # Get timeblocks from the enroll_academic_process that are not retired
    enroll_timeblocks = self.timeblocks.joins(:timetable => {:section => :academic_records})
                                   .where.not('academic_records.status': 3)
    
    # Get timeblocks from the provided timetable
    timetable_timeblocks = timetable.timeblocks
    
    # Compare each timeblock from the timetable with enroll timeblocks
    timetable_timeblocks.each do |timetable_block|
      enroll_timeblocks.where(day: timetable_block.day).each do |enroll_block|
        # Check if there's overlap in time
        if ((enroll_block.start_time&.to_i < timetable_block.end_time&.to_i) and 
            (timetable_block.start_time&.to_i < enroll_block.end_time&.to_i))
          return true
        end
      end
    end
    
    return false
  end

	def confirm_with_email
		UserMailer.enroll_confirmation(self.id).deliver_later if self.update(enroll_status: :confirmado)
	end
  
  def not_confirmado?
    (reservado? or preinscrito?)
  end

  def self.type_label_by_enroll type
    # [:preinscrito, :reservado, :confirmado, :retirado]
    case type
    when 'preinscrito' 
      'info'
    when 'reservado' 
      'warning'
    when 'confirmado' 
      'success'
    else
      ''
    end
  end

  def get_permanece_status
    get_regulation
  end
  def get_regulation
    if permiso_para_no_cursar?
      reglamento_aux = :permiso_para_no_cursar
    else
      reglamento_aux = :regular
      if !(self.grade.academic_records.qualified.any?)
        reglamento_aux = :nuevo
      elsif total_retire?
        reglamento_aux = :retiro_total
      elsif self.academic_records.sin_calificar.any?
        reglamento_aux = :por_calificar
      elsif self.academic_records.coursed.any?
        if coursed_but_not_approved_any?
          reglamento_aux = :articulo3
          iep_anterior = self.before_enrolled
          if iep_anterior&.coursed_but_not_approved_any?
            reglamento_aux = :articulo6
            iep_anterior2 = iep_anterior.before_enrolled
            if iep_anterior2&.coursed_but_not_approved_any?
              reglamento_aux = :articulo7
            end
          end
        end
      end
    end

    return reglamento_aux
  end

  def coursed_but_not_approved_any?
    self.academic_records.any? and !(self.academic_records.sin_calificar.any?) and !(self.academic_records.aprobado.any?)
  end
  def finished?
    academic_records.any? and (academic_records.count.eql? academic_records.qualified.count)
  end

  def fully_qualified?
    finished?
  end

  def before_enrolled
    process_before_id = academic_process&.process_before_id
    process_before_id ? grade.enroll_academic_processes.where(academic_process_id: process_before_id).first : nil
  end

  def not_pass_any?
    (academic_records.any? and !academic_records.aprobado.any?)
  end

  def any_permanence_articulo?
    (self.articulo3? or self.articulo6? or self.articulo7?)
  end

  def set_default_values_by_import
    self.enroll_status = :confirmado
    self.permanence_status = :nuevo
  end

  # def is_enroll_pci?
  #   !(grade.school&.id.eql? academic_process.school_id)
  # end
  def enrolling?
    # school.academic_processes.where(modality: grade.study_plan_modality).enrolls
    # academic_process.eql? school.academic_processes.first
    academic_process&.enrolling?

  end

  def admin_enrolling?
    academic_process&.enrolling? or academic_process.eql? school.academic_processes.where(modality: grade.study_plan_modality).first
  end

  def pay_amount
    if self.nuevo?
      academic_process.registration_amount_new
    elsif self.reincorporado?
      academic_process.registration_amount_restart
    else
      academic_process.registration_amount
    end
  end

  def historical?
    !enrolling?
  end

  def resume_sections
    self.academic_records.includes(:section).map{|ar| ar.section.desc_subj_code}
  end

  def total_academic_records
    self.subjects.count
  end

  def total_subjects
    subjects.count
  end

  def total_subjects_coursed
    academic_records.total_subjects_coursed
  end

  def total_subjects_approved
    academic_records.total_subjects_approved
  end

  def total_subjects_not_retired
    subjects.where.not('academic_records.status': 3).count
  end

  def total_credits
    subjects.sum(:unit_credits)
  end

  def total_credits_not_retired
    subjects.where.not('academic_records.status': 3).sum(:unit_credits)
  end  

  def short_name
    "#{self.school.code}_#{self.academic_process.process_name}_#{self.student.user_ci}"
  end

  def name
    "(#{self.school.code}) #{self.academic_process.process_name}:#{self.student.name}" if ( self.period and self.school and self.student)
  end

  def enroll_label_status
    # ["CO", "INS", "NUEVO", "PRE", "REINC", "RES", "RET", "VAL"] 
    case self.enroll_status
    when 'confirmado'
      label_color = 'success'
    when 'preinscrito'
      label_color = 'info'
    when 'retirado'
      label_color = 'danger'
    else
      label_color = 'secondary'
    end
    return ApplicationController.helpers.label_status("bg-#{label_color}", self.enroll_status&.titleize)
  end

  def enroll_label_status_to_list
    aux = enroll_label_status
    if not_confirmado?
      aux += "<a href='/enroll_academic_processes/#{self.id}/update_permanece_status?enroll_academic_process[enroll_status]=confirmado' data-method='POST' class='label label-sm bg-success ms-1' data-bs-placement='right' data-bs-original-title='Confirmación rápida' rel='tooltip' data-bs-toggle='tooltip'><i class='fa fa-check'></i></a>".html_safe
    end
    return aux
  end

  def label_permanence_status
    # [:nuevo, :regular, :reincorporado, :articulo3, :articulo6, :articulo7, :intercambio, :desertor, :egresado, :egresado_doble_titulo]  
    label_color = 'info'
    case self.permanence_status
    when 'articulo3'
      label_color = 'warning'
    when 'articulo6'
      label_color = 'danger'
    when 'articulo7'
      label_color = 'dark'
    end
    return ApplicationController.helpers.label_status("bg-#{label_color}", self.permanence_status&.titleize)
  end

  def region
    grade&.region&.titleize
  end

  rails_admin do
    navigation_label 'Config Específica'

    navigation_icon 'fa-solid fa-calendar-check'
    weight 0
    
    show do
      field :enrolling do
        label do 
          "INSCRIPCIÓN #{bindings[:object].academic_process&.short_desc} de #{bindings[:object].user.reverse_name}"
        end
        visible do
          current_user = bindings[:view]._current_user
          (current_user and current_user.admin and current_user.admin.authorized_manage? 'EnrollAcademicProcess')
        end
        formatted_value do          
          if bindings[:object].admin_enrolling?
            totalCreditsReserved = bindings[:object].total_credits_not_retired
            totalSubjectsReserved = bindings[:object].total_subjects_not_retired

            bindings[:view].render(partial: '/enroll_academic_processes/form', locals: {enroll: bindings[:object], grade: bindings[:object].grade, academic_process: bindings[:object].academic_process, totalCreditsReserved: totalCreditsReserved, totalSubjectsReserved: totalSubjectsReserved})
          else
            bindings[:view].render(partial: "/academic_records/making_historical", locals: {enroll: bindings[:object]})
          end
        end
      end      
    end

    edit do
      fields :grade, :academic_process, :enroll_status, :permanence_status
    end

    list do
      search_by :custom_search
      # filters [:process_name, :student]
      scopes [:todos, :preinscrito, :reservado, :confirmado, :retirado, :con_reporte_de_pago, :sin_reporte_de_pago]

      
      field :school do
        sticky true 
        searchable :name
        sortable :name
      end

      field :study_plan do
        filterable :code
        searchable :code
      end
      
      field :academic_process do
        sticky true
        column_width 100
        searchable :name
        filterable :name
        sortable :name
        pretty_value do
          value.process_name
        end
      end
      
      field :student do
        column_width 340
        # searchable ['users.ci', 'users.first_name', 'users.last_name']
        # filterable ['users.ci', 'users.first_name', 'users.last_name']
        # sortable ['users.ci', 'users.first_name', 'users.last_name']
      end
      field :enroll_status_label do
        label 'Estado'
        sticky true 
        column_width 150
        searchable :enroll_status
        filterable false
        sortable false
        formatted_value do
          bindings[:object].enroll_label_status_to_list
        end
      end
      
      field :total_subjects do
        label 'Tot Asig'
        column_width 40
      end

      field :total_credits do
        label 'Tot Cred'
        column_width 40
      end

      field :created_at do
        label 'Fecha de Inscripción'
        searchable false
      end

      field :permanence_status do
        pretty_value do
          bindings[:object].label_permanence_status
        end
      end

      field :payment_reports do
        # filterable true #"joins(:payment_reports).count"
        # queryable true
      end

      field :payment_report_status do
        label 'Estado Reporte Pago'
        formatted_value do
          bindings[:object].payment_reports&.map(&:label_status).to_sentence.html_safe
        end
      end

      field :region do
        label 'Región'
        # searchable :enroll_status
        
        queryable false
        filterable false
        sortable false
      end

      
      fields :efficiency, :simple_average, :weighted_average
    end

    export do
      fields :student, :user
      fields :grade, :enroll_status, :permanence_status, :study_plan
      
      field :efficiency do
        label 'Eficiencia en el Período'
      end
      
      field :simple_average do
        label 'Promedio en el Período'
      end
      field :weighted_average do
        label 'Ponderado en el Período'
      end

      field :period do
        label 'Período'
        column_width 100
        searchable :name
        # filterable 'periods.name'
        sortable :name
      end

      field :resume_sections do
        label 'Resumen Asignaturas del Periodo'
      end
      field :total_subjects do
        label 'Total Asignaturas en Periodo'
      end
      field :total_credits do
        label 'Total Créditos en Periodo'
      end
      field :payment_reports do
        label 'Reporte de Pago'
      end

    end
  end

  def is_the_last_enroll_of_grade?
    self.grade.last_enrolled.eql? self
  end


  def total_credits_coursed
    academic_records.total_credits_coursed
  end

  def total_credits_approved
    academic_records.total_credits_approved
  end

  def efficiency_desc
    if efficiency.nil?
      '--'
    else
      (efficiency).round(2)
    end
  end

  def simple_average_desc
    if simple_average.nil?
      '--'
    else
      (simple_average).round(2)
    end
  end

  def weighted_average_desc
    if weighted_average.nil?
      '--'
    else
      (weighted_average).round(2)
    end
  end

  def calculate_efficiency
    cursados = self.total_subjects_coursed
    aprobados = self.total_subjects_approved
    if cursados < 0 or aprobados < 0
      0.0
    elsif cursados == 0 or (cursados > 0 and aprobados >= cursados)
      1.0
    else
      (aprobados.to_f/cursados.to_f).round(4)
    end
  end

  def calculate_average
    aux = academic_records.promedio
    (aux&.is_a? BigDecimal) ? aux.to_f.round(4) : self.simple_average
  end

  def calculate_weighted_average 
    aux = academic_records.weighted_average
    cursados = self.total_credits_coursed
    (cursados > 0 and aux) ? (aux.to_f/cursados.to_f).round(4) : self.weighted_average
  end


  private

  def update_current_permanence_status_on_grade
    grade.update(current_permanence_status: self.permanence_status) if is_the_last_enroll_of_grade?
    
  end

  def paper_trail_update
    changed_fields = self.changes#.keys - ['created_at', 'updated_at']
    changed_fields = changed_fields.map do |fi|
      if fi[0] != 'updated_at'
        elem = I18n.t("activerecord.attributes.#{self.model_name.param_key}.#{fi[0]}").to_s
        elem += " de #{fi[1][0]} a #{fi[1][1]}"
      end
    end
    object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
    self.paper_trail_event = "¡#{object} actualizada en: #{changed_fields.to_sentence}"
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
