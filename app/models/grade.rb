# == Schema Information
#
# Table name: grades
#
#  id                        :bigint           not null, primary key
#  appointment_time          :datetime
#  current_permanence_status :integer          default("nuevo"), not null
#  duration_slot_time        :integer
#  efficiency                :float
#  enrollment_status         :integer          default("preinscrito"), not null
#  graduate_status           :integer
#  region                    :integer          default("no_aplica")
#  registration_status       :integer
#  simple_average            :float
#  weighted_average          :float
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  admission_type_id         :bigint           not null
#  enabled_enroll_process_id :bigint
#  language1_id              :bigint
#  language2_id              :bigint
#  start_id                  :bigint
#  start_process_id          :bigint
#  student_id                :bigint           not null
#  study_plan_id             :bigint           not null
#
# Indexes
#
#  index_grades_on_admission_type_id             (admission_type_id)
#  index_grades_on_enabled_enroll_process_id     (enabled_enroll_process_id)
#  index_grades_on_start_id                      (start_id)
#  index_grades_on_start_process_id              (start_process_id)
#  index_grades_on_student_id                    (student_id)
#  index_grades_on_student_id_and_study_plan_id  (student_id,study_plan_id) UNIQUE
#  index_grades_on_study_plan_id                 (study_plan_id)
#
# Foreign Keys
#
#  fk_rails_...  (admission_type_id => admission_types.id)
#  fk_rails_...  (enabled_enroll_process_id => academic_processes.id)
#  fk_rails_...  (language1_id => languages.id) ON DELETE => nullify ON UPDATE => cascade
#  fk_rails_...  (language2_id => languages.id) ON DELETE => nullify ON UPDATE => cascade
#  fk_rails_...  (start_process_id => academic_processes.id) ON DELETE => nullify ON UPDATE => cascade
#  fk_rails_...  (student_id => students.user_id) ON DELETE => cascade ON UPDATE => cascade
#  fk_rails_...  (study_plan_id => study_plans.id)
#
class Grade < ApplicationRecord
  include Numerizable
  has_paper_trail on: [:create, :destroy, :update], limit: nil

  before_create :paper_trail_create
  before_destroy :paper_trail_destroy
  before_update :paper_trail_update  

  NORMATIVE_TITLE = "NORMAS SOBRE EL RENDIMIENTO MÍNIMO Y CONDICIONES DE PERMANENCIA DE LOS ALUMNOS EN LA U.C.V"

  ARTICULO7 = 'Artículo 7°. El alumno que, habiéndose reincorporado conforme al artículo anterior, dejare nuevamente de aprobar el 25% de la carga que curse, o en todo caso, el que no apruebe ninguna asignatura durante dos períodos consecutivos, no podrá incorporarse más a la misma Escuela o Facultad, a menos que el Consejo de Facultad, previo estudio del caso, autorice su reincorporación.'

  ARTICULO6 = "Artículo 6°. El alumno que al final del semestre de recuperación no alcance nuevamente a aprobar el 25% de la carga académica que cursa o en todo caso a aprobar por lo menos una asignatura, no podrá reinscribirse en la Universidad Central de Venezuela, en los dos semestres siguientes. Pasados éstos, tendrá el derecho de reincorporarse en la Escuela en la que cursaba sin que puedan exigírsele otros requisitos que los trámites administrativos usuales. Igualmente, podrá inscribirse en otra Escuela diferente con el Informe favorable del Profesor Consejero y de la Unidad de Asesoramiento Académico de la Escuela a la cual pertenecía, y la aprobación por parte del Consejo de Facultad a la cual solicita el traslado. </br></br> Usted ha sido suspendido por dos semestres (un año) y deberá solicitar la reincorporación, según las fechas y los procedimientos establecidos por el Dpto. de Control de Estudios de la Facultad."

  ARTICULO3 = "Artículo 3°. Todo alumno que en un período no apruebe el 25% de la carga académica que curse o que, en todo caso no apruebe por lo menos una asignatura, deberá participar obligatoriamente en el procedimiento especial de recuperación establecido en estas normas. </br></br> Esto quiere decir que usted puede inscribirse normalmente y debe inscribir la carga mínima permitida por el Plan de Estudios de su Escuela. Usted debe aprobar al menos una asignatura para superar esta sanción. Si usted reprueba nuevamente todas las asignaturas inscritas, será sancionado con el Art. 06, es decir, será suspendido por dos sementres (un año) y deberá solicitar la reincorporación, según las fechas y los procedimientos establecidos por el Dpto. de Control de Estudios de la Facultad."


  # ASSOCIATIONS:
  belongs_to :student, primary_key: :user_id
  belongs_to :study_plan
  belongs_to :admission_type
  belongs_to :enabled_enroll_process, foreign_key: 'enabled_enroll_process_id', class_name: 'AcademicProcess', optional: true
  belongs_to :academic_process, foreign_key: 'start_process_id', class_name: 'AcademicProcess', optional: true
  # Igual al siguiente
  belongs_to :start_process, foreign_key: 'start_process_id', class_name: 'AcademicProcess', optional: true

  has_one :school, through: :study_plan
  has_one :user, through: :student

  belongs_to :language1, class_name: 'Language', foreign_key: 'language1_id', optional: true
  belongs_to :language2, class_name: 'Language', foreign_key: 'language2_id', optional: true
  
  has_many :enroll_academic_processes, dependent: :destroy
  has_many :academic_processes, through: :enroll_academic_processes
  has_many :academic_records, through: :enroll_academic_processes

  has_many :payment_reports, as: :payable, dependent: :destroy

  # ENUMERIZE:
  enum registration_status: {pendiente: 0, secretaria: 1, facultad: 2, escuela: 3}
  enum enrollment_status: {preinscrito: 0, asignado: 1, confirmado: 2}
  enum graduate_status: {cursante: 0, tesista: 1, posible_graduando: 2, graduando: 3, graduado: 4, postgrado: 5}
  enum current_permanence_status: PERMANENCE_STATUSES
  enum region: {no_aplica: 0, amazonas: 1, barcelona: 2, barquisimeto: 3, bolivar: 4, capital: 5}


  # VALIDATIONS:
  # validates :student, presence: true
  validates :study_plan, presence: true
  validates :admission_type, presence: true

  validates_uniqueness_of :study_plan, scope: [:student], message: 'El estudiante ya tiene el grado asociado', field_name: false

  #SCOPES:
  scope :with_day_enroll_eql_to, -> (day){ where(appointment_time: day.all_day)}
  scope :with_appointment_time, -> { where("appointment_time IS NOT NULL")}
  scope :with_appointment_time_eql_to, -> (dia){ where("date(appointment_time) = '#{dia}'")}
  scope :without_appointment_time, -> { where('grades.appointment_time': nil)}

  # scope :with_enrollments_in_period, -> (period_id) { joins(academic_records: {section: {course: :academic_process}}).where('(SELECT COUNT(*) FROM academic_records WHERE academic_records.estudiante_id = grades.student_id) > 0 and secciones.periodo_id = ?', periodo_id) }

  # scope :with_enrollments_in_period, -> (period_id) { joins(academic_records: {section: {course: :academic_process}}).where('(SELECT COUNT(*) FROM academic_records WHERE academic_records.enroll_academic_process_id = enroll_academic_processes.id) > 0 and academic_processes.period_id = ?', period_id) }

  # scope :with_enrollments_in_period, -> (period_id) { joins(academic_records: {section: {course: :academic_process}}).where('academic_processes.period_id = ?', period_id).group(:'enroll_academic_processes.id').having('COUNT(*) > 0').count}

  # ATENCIÓN: EL UNIQ DEBO HACERLO EN EL LLAMADO DEL SCOPE ANTERIOR YA QUE DE LO CONTRARIO DEVUELVE LA CANTIDAD DE REGISTROS VINCULADOS A LAS enroll_academic_processes

  scope :enrolled_in_academic_process, -> (academic_process_id) { joins(:enroll_academic_processes).where('enroll_academic_processes.academic_process_id': academic_process_id) }

  # scope :not_enrolled_in_academic_process, -> (academic_process_id) { joins(:enroll_academic_processes, :academic_processes).where.not("academic_processes.id": academic_process_id) }

  scope :not_enrolled_in_academic_process, -> (academic_process_id) {joins(:enroll_academic_processes).where('enroll_academic_processes.academic_process_id != ?', academic_process_id)}

  scope :left_not_enrolled_in_academic_process, -> (academic_process_id) {left_joins(:enroll_academic_processes).where('enroll_academic_processes.academic_process_id != ?', academic_process_id)}


  scope :sort_by_numbers, -> () {order([efficiency: :desc, simple_average: :desc, weighted_average: :desc])}
  
  scope :total_with_enrollments_in_period, -> (period_id) { with_enrollments_in_period(period_id).uniq.count }
  
  scope :valid_to_enrolls, -> (academic_process_id, process_before_id) {valid_to_enrolls_pre(process_before_id).or(Grade.special_authorized(academic_process_id))}

  scope :valid_to_enrolls_pre, -> (process_before_id) {without_appointment_time.current_permanence_valid_to_enroll.enrolled_in_academic_process(process_before_id)}

  scope :current_permanence_valid_to_enroll, -> {where('grades.current_permanence_status': [:regular, :reincorporado, :articulo3])}

  scope :others_permanence_invalid_to_enroll, -> {where(current_permanence_status: Numerizable::PERMANENCE_STATUSES - [:regular, :reincorporado, :articulo3])}

  scope :special_authorized, -> (academic_process_id) {where(enabled_enroll_process_id:academic_process_id )}

  # without_appointment_time.enrolled_in_academic_process(process_before_id)



  # scope :with_academic_records, -> { where('(SELECT COUNT(*) FROM  "grades" INNER JOIN "enroll_academic_processes" ON "enroll_academic_processes"."grade_id" = "grades"."id" INNER JOIN "academic_records" ON "academic_records"."enroll_academic_process_id" = "enroll_academic_processes"."id") > 0') }

  scope :with_academic_records, -> {joins(:academic_records)}
  
  scope :without_academic_records, -> { where('(SELECT COUNT(*) FROM  "grades" INNER JOIN "enroll_academic_processes" ON "enroll_academic_processes"."grade_id" = "grades"."id" INNER JOIN "academic_records" ON "academic_records"."enroll_academic_process_id" = "enroll_academic_processes"."id") IS NULL') }

  scope :without_enroll_academic_processes, -> {left_joins(:enroll_academic_processes).where('enroll_academic_processes.grade_id': nil)}

  # AVANCES EN PIGGLY-SCOPE
  # scope :without_enroll_in_academic_processes, -> (academic_process_id) {left_joins(:enroll_academic_processes).where('enroll_academic_processes.grade_id': nil, 'enroll_academic_processes.academic_process_id': academic_process_id)}

  scope :custom_search, -> (keyword) { joins(:user, :school).where("users.ci ILIKE '%#{keyword}%' OR schools.name ILIKE '%#{keyword}%'") }

  # FUNCTIONS:
  def payment_process
    start_process
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

	def csv_academic_records
		require 'csv'
		
		csv_data =CSV.generate(headers: true, col_sep: ";") do |csv|

			csv << %w(CEDULA ASIGNATURA DENOMINACION CREDITO NOTA_FINAL NOTA_DEFI TIPO_EXAM PER_LECTI ANO_LECTI SECCION PLAN1)
      academic_records.each do |academic_record|

        sec = academic_record.section
        asig = academic_record.subject
    
        # ============ Mover a Inscripcionseccion =========== #
        nota_def = academic_record.cal_alfa_to_csv
        nota_final = academic_record.cal_alfa_to_csv 'final'
        # ============ Mover a Inscripcionseccion =========== #
    
        csv << [user.ci, asig.code, asig.name, asig.unit_credits, nota_final, nota_def, 'F', academic_record.academic_process&.period_type&.code, academic_record.academic_process&.period&.year, sec&.code, academic_record.study_plan&.code]
    
        if academic_record.post_q?
          nota_final = nota_def = academic_record.post_q&.value_to_02i
          csv << [user.ci, asig.code, asig.name, asig.unit_credits, nota_final, nota_def, 'F', academic_record.academic_process&.period_type&.code, academic_record.academic_process&.period&.year, sec&.code, academic_record.study_plan&.code]
        end

      end
		end

		return csv_data
	end

  
  # PARCHE PARA CONTEMPLR CASOS DE EDUCACIÓN:

  def study_plan_modality
    study_plan&.modality
  end
  def get_current_permanence_status
    # current_permanence_status: nuevo: 0, regular: 1, reincorporado: 2, articulo3: 3
    # articulo6: 4, articulo7: 5, intercambio: 6, desertor: 7, egresado: 8, 
    # egresado_doble_titulo: 8, permiso_para_no_cursar: 9

    if is_new?
      :nuevo
    elsif current_process = self.school.academic_processes.first
      before_eap = self.enroll_academic_processes.where(academic_process_id: current_process.id).first
      if before_eap.nil? 
        :reincorporado
      else
        before_eap.permanence_status
      end
    else
      :regular
    end
  
  end


  # Import's Functions:

  def grado
    Grado.where(estudiante_id: user&.ci, escuela_id: school&.code).first
  end

  def import_new_grade grado

    self.current_permanence_status = grado.reglamento
  
    if grado.reincorporado?
      self.current_permanence_status = :reincorporado
      self.enrollment_status = :confirmado
    else
      self.enrollment_status = grado.estado_inscripcion
    end
    self.graduate_status = grado.estado
    self.region = grado.region
    
    self.registration_status = :escuela
    
    self.admission_type = AdmissionType.translate_tipo_ingreso grado.tipo_ingreso
    
    # Periodo Inicial
    if grado.iniciado_periodo_id
      academic_process_start_name = "#{grado.escuela_id} | #{grado.iniciado_periodo_id}"
      ap = AcademicProcess.where(name: academic_process_start_name).first
      self.start_process_id = ap&.id
    end

    if self.save
      print '+'
      # Historial Planes
      grado.historialplanes.order(created_at: :asc).each do |histo_plan|
        sp = StudyPlan.where(code: histo_plan.plan_id).first
        self.study_plan_id = sp.id
        self.save
      end
      
      # Combinacion de Idiomas
      if grado.escuela_id.eql? 'IDIO' and combinaciones = grado.estudiante&.combinaciones	
        combinaciones.order(created_at: :asc).each do |combinacion|
          idiama_descrpcion = combinacion.idioma1&.descripcion
          language = Language.where(name: idiama_descrpcion).first
          self.language1_id = language&.id
          idiama_descrpcion = combinacion.idioma2&.descripcion
          language = Language.where(name: idiama_descrpcion).first								
          self.language2_id = language&.id
          self.save if self.changed?
        end
      end

      # Reportepago
      if grado.reportepago and adjunto = Adjunto.where(name: 'respaldo', record_type: 'Reportepago', record_id: grado.reportepago_id).first
        reporte = grado.reportepago
        
        payment_preport = PaymentReport.new
        payment_preport.payable_type = 'Grade'
        payment_preport.payable_id =  self.id
        payment_preport.amount = reporte.monto
        payment_preport.status = :Validado
        payment_preport.transaction_id = reporte.numero
        payment_preport.receiving_bank_account_id = BankAccount.first.id
        payment_preport.transaction_date = reporte.fecha_transaccion
        payment_preport.transaction_type = reporte.tipo_transaccion
        
        # Buscar Banco
        bank = Bank.find_by(code: reporte.banco_origen_id)
        payment_preport.origin_bank_id = bank.id
        
        # Adjunto
        blob_id = adjunto.adjuntoblob_id
        blob = ActiveStorage::Blob.find blob_id							
        payment_preport.voucher.attach blob if blob
        print payment_preport.save ? 'R√' : 'Rx'
      end
      return true
    else
      (p "x#{grade.errors.full_messages.to_sentence} |#{grado.estudiante_id}")
      return false
    end

  end

  def help_msg
    unless self.school&.faculty&.contact_email.blank?
      "Puede escribir al correo: #{self.school&.faculty&.contact_email} para solicitar ayuda."
    end
  end

  def self.normative
    NORMATIVE_TITLE
  end

  def normative_by_article
    if self.articulo7?
      ARTICULO7
    elsif self.articulo6?
      ARTICULO6
    elsif self.articulo3?
      ARTICULO3
    else
      ""
    end
  end

  def last_enrolled
    enroll_academic_processes.joins(:academic_process).order('academic_processes.name': :desc).first
  end

  def academic_processes_unenrolled
    school.academic_processes.joins(period: :period_type).order('periods.year DESC, period_types.code DESC').reject{|ap|self.academic_processes.ids.include?(ap.id)}
  end

  # ENROLLMENT
  def valid_to_enroll_in academic_process
    
    if self.enabled_enroll_process.eql?(academic_process)
      return true
    else
      academic_process_before = academic_process&.process_before
      if (academic_process_before and self.enroll_academic_processes.of_academic_process(academic_process_before.id).any?) and (['regular', 'reincorporado', 'articulo3', 'retiro_periodo'].include? self.current_permanence_status)
        return true
      end
    end
    return false
  end

  # APPOINTMENT_TIME:
  def has_a_appointment_time?
    (self.appointment_time.nil? or self.duration_slot_time.nil?) ? false : true
  end

  def can_enroll_by_apponintment? #puede_inscribir?
    ((has_a_appointment_time?) and (Time.zone.now > self.appointment_time) and (Time.zone.now < self.appointment_slot_time) ) ? true : false
  end

  def enroll_is_in_future?
    if self.appointment_slot_time
      (self.appointment_slot_time > Time.zone.now) 
    else
      false
    end
  end

  def appointment_slot_time
    (has_a_appointment_time?) ? self.appointment_time+self.duration_slot_time.minutes : nil    
  end

  def appointment_time_desc_short
    if self.appointment_time
      (I18n.localize(self.appointment_time, format: "%d/%m/%Y %I:%M%p")) 
    else
      '--'
    end
  end

  def appointment_from_to
    if self.appointment_time and self.appointment_slot_time
      aux = (I18n.localize(self.appointment_time, format: "%A, %d de %B de %Y de %I:%M%p")) 
      aux += (I18n.localize(self.appointment_slot_time, format: " a %I:%M%p"))
      return aux
    end
  end

  def appointment_from_to_short
    if self.appointment_time and self.appointment_slot_time
      aux = (I18n.localize(self.appointment_time, format: "%d/%m/%y %I:%M%p")) 
      return aux
    end
  end

  
  def appointment_passed
    if self.appointment_slot_time
      (I18n.localize(self.appointment_slot_time, format: "%A %d de %B de %Y hasta las %I:%M%p"))
    end
  end

  def appointment_from
    I18n.l(self.appointment_time, format: "%I:%M %p") if self.appointment_time
  end

  def appointment_to
    I18n.l(self.appointment_time+self.duration_slot_time&.minutes, format: "%I:%M %p") if (self.appointment_time and self.duration_slot_time&.minutes)
  end

  def appointment_time_desc
    if (appointment_time and duration_slot_time)
      aux = ""
      aux += "#{I18n.l(appointment_time)}" if appointment_time
      aux += " | duración: #{duration_slot_time} minutos" if duration_slot_time
      return aux
    end
  end

  def label_languages
    if language1 and language2
      ApplicationController.helpers.label_status_with_tooltip('bg-success', "#{language1&.short_name} - #{language2&.short_name}", "#{language1&.name} - #{language2&.name}")
    else
      ApplicationController.helpers.label_status('bg-secondary', 'Sin Información')
    end
  end

  def label_registration_status    
    ApplicationController.helpers.label_status('bg-info', registration_status&.titleize)
  end

  def label_graduate_status
    ApplicationController.helpers.label_status('bg-info', graduate_status&.titleize)
  end

  def label_admission_type
    ApplicationController.helpers.label_status('bg-info', admission_type&.name&.titleize)
  end
  
  def label_start_process
    ApplicationController.helpers.label_status('bg-info', start_process&.process_name)
  end

  def label_study_plan
    ApplicationController.helpers.label_status('bg-info', study_plan&.code)
  end

  def label_cita_horaria
    aux = 'bg-secondary'
    if appointment_time
      if appointment_time&.today?
        aux = 'bg-warning'
      elsif appointment_time > Date.today
        aux = 'bg-success'
      end
    end
    ApplicationController.helpers.label_status_with_tooltip(aux, appointment_from_to_short, appointment_from_to)
  end  

  def label_status_enroll_academic_process(academic_process_id)
    if iep = self.enroll_academic_processes.of_academic_process(academic_process_id).first
      iep.enroll_label_status
    else
      ApplicationController.helpers.label_status('bg-secondary', 'Sin Inscripción')
    end
  end

  def any_approved?
    academic_records.aprobado.any?
  end

  def current_level
    #OJO: DEBERÍA ESTAR ASOCIADO AL MAX ORDINAL DE LAS ASIGNATURAS DE LA ESCUELA
    # OJO: CASO 5 AÑO, ES UNA SOLA MATERIA Y CUMPLE LA CONDICIÓN
    begin
      levels = study_plan.school.subjects.order(:ordinal).group(:ordinal).count.max.first
    rescue Exception
      levels = study_plan.levels 
    end
    levels_response = []
    arrastre = 1
    levels.times do |level|
      level = level+1
      apporved_level = true
      
      study_plan.requirement_by_levels.where(level: level).each do |requirement|
        tipo = requirement.subject_type.name.downcase
        total_required_subjects = requirement.required_subjects
        total_approved_subjects = total_subjects_approved_by_type_subject_and_level level, tipo

        # p " Level: #{level} de #{levels} | Tipo: #{tipo} |  Requirement: #{total_required_subjects}  Aprobados: #{total_approved_subjects}   ".center(500, "=")

        if !total_required_subjects.nil? and total_required_subjects > total_approved_subjects 
          apporved_level = false 
          arrastre = 2 if ((total_required_subjects - total_approved_subjects).eql? 1 and !level.eql? levels) 
        end
      end
      levels_response << level unless apporved_level
    end
    if levels_response.eql? []
      return [1]
    else
      return levels_response.first(arrastre)
    end
  end

  # def current_level
  #   # OJO: REVISAR ALGORITMO, SIEMPRE SALE LEVEL 1 🤮
  #   levels = study_plan.levels
  #   levels.times do |level|
  #     level = level+1
  #     p "    level: #{level}    ".center(250, "#")
  #     study_plan.requirement_by_levels.where(level: level).each do |requirement|
  #       required_subjects = requirement.required_subjects
  #        # ATENCIÓN: Condición especial para Odontología por el campo modality que fue sustituido por SubjectType
  #        tipo = requirement.subject_type.name.downcase
  #        # type = requirement.subject_type_id
  #        # OJO: 👆🏽 Así debe ser en el Plus 

  #        total_subjects_approved = total_subjects_approved_by_type_subject_and_level level, tipo


  #        diference = (required_subjects - total_subjects_approved).abs
  #        p " Level: #{level} de #{levels} | Tipo: #{tipo} |  Requirement: #{required_subjects}  Aprobados: #{total_subjects_approved}  Diference: #{diference}   ".center(500, "=")
  #       if level.eql? levels or (required_subjects > 0 and required_subjects > total_subjects_approved and diference > 1) 
  #         return [level]
  #       elsif diference.eql? 1
  #         return [level, level+1]
  #       end
  #     end
  #   end
    
  #   return [levels]
  # end

  def level_offer

    total_approved_by_levels = self.academic_records.aprobado.joins(:subject).group('subjects.ordinal').count
    total_approved_by_levels = total_approved_by_levels.to_a
    
    levels_not_approved = []
    begin
      if total_approved_by_levels.any?
        last_approved_level = total_approved_by_levels.max.first
        # p "    ULTIMO NIVEL: #{last_approved_level}     ".center(2000, "=")
        total_approved_by_levels.each do |approved_by_level|
          level = approved_by_level.first
          # p "LEVEL: #{level}"
          total_approved = approved_by_level.last
          # p "APROBADAS: #{total_approved}"
          # Es solo para el tipo de asignatura obligatoria ya que las otras tienen otro comportamiento:
          requirement_by_level = self.study_plan.requirement_by_levels.of_subject_type(SubjectType.obligatoria.id).of_level(level).first
          required_subjects = requirement_by_level&.required_subjects
          # p "REQUERIMIENTOS: #{required_subjects}"
        
          if (total_approved < required_subjects)
            # Nivel No Aprovado completamente, se incluye en la oferta
            levels_not_approved << level 
          end
          # Si es el ultimo nivel con aprovadas y no es el 5to y la diferencia entre aprobadas y requeridas es uno:
          if level.eql? last_approved_level and level < 5 and (total_approved+1) >= required_subjects
            # p "     EXTRA BALLL!!!     ".center(2000, "#")
            # Último nivel aprovado
            levels_not_approved << level+1
          end
        end
      else
        levels_not_approved << 1
      end
      return levels_not_approved#.last(2)
    rescue Exception
      return 1
    end
  end


  # OFERTA POR ASIGNATURAS
  def subjects_offer_by_level_approved
    # Buscamos los ids de las asignaturas aprobadas
    asig_aprobadas_ids = self.subjects_approved_ids    
    # Subject.where(ordinal: current_level).where.not(id: asig_aprobadas_ids)
    Subject.where(ordinal: level_offer).or(Subject.optativa).where.not(id: asig_aprobadas_ids)
  end


  def subjects_offer_by_dependent

    if is_new? or !any_approved?
      # Si es nuevo o no tiene asignaturas aporvadas, le ofertamos las de 1er año
      school.subjects.independents#.where(ordinal: 1)
    else
      # Buscamos los ids de las asignaturas aprobadas
      asig_aprobadas_ids = self.subjects_approved_ids

      # Buscamos por ids las asignaturas que dependen de las aprobadas
      dependent_subject_ids = SubjectLink.in_prelation(asig_aprobadas_ids).not_in_dependency(asig_aprobadas_ids).pluck(:depend_subject_id).uniq

      ids_subjects_positives = []

      # Ahora por cada asignatura válida miramos sus respectivas dependencias a ver si todas están aprobadas

      # OJO: REVISAR, Creo que este paso es REDUNDANTE, si tienes las dependencias de las aprovadas, no deberías mirar si aprobó las asignaturas de esas dependencias. 
      # OJO2: ¡Revisado! y sí debe ir, porque sino oferta asignaturas que no debe
      dependent_subject_ids.each do |subj_id|
        ids_aux = SubjectLink.where(depend_subject_id: subj_id).map{|dep| dep.prelate_subject_id}
        ids_aux.reject!{|id| asig_aprobadas_ids.include? id}
        ids_subjects_positives << subj_id if (ids_aux.eql? []) #Si aprobó todas las dependencias
      end

      # Buscamos las asignaturas sin prelación
      ids_subjects_independients = self.school.subjects.independents.not_inicial.ids

      # Sumamos todas las ids ()
      asignaturas_disponibles_ids = ids_subjects_positives + ids_subjects_independients

      Subject.where(id: asignaturas_disponibles_ids)
    end
  end

  def is_new?
    enroll_academic_processes.count <= 1
  end

  def academic_records_any?
    self.academic_records.any?
  end

  def user
    student.user if student
  end

  def name
    "#{study_plan.name}: #{student.name} (#{admission_type.name})" if study_plan and student and admission_type
  end

  def short_name
    if (study_plan and user)
      "#{study_plan&.code}_#{user.ci}"
    else
      "#{id}"
    end
  end

  def description
    "Plan de Estudio: #{study_plan.name}, Admitido vía: #{admission_type.name}, Estado de Inscripción: #{registration_status.titleize}" if (study_plan and admission_type and registration_status)
  end


  # NUMBERSTINY:

  # TOTALS CREDITS:

  def credits_completed_by_type tipo
    academic_records.aprobado.by_subject_types(tipo).total_credits
  end

  def total_credits
    self.academic_records.total_credits
  end

  # TOMAR EN CUENTA QUE LOS CREDITOS O ASIGNATURAS REGISTRADAS PRO EQUIVALENCIA DEBEN SER APROBADAS
  # def total_credits_eq
  #   self.academic_records.total_credits_equivalence
  # end

  def total_credits_approved_by_type_subject_and_level tipo, level
    academic_records.total_credits_approved_by_level_and_type tipo, level
  end

  def total_subjects_approved_by_type_subject_and_level level, tipo
    academic_records.total_subjects_approved_by_level_and_type level, tipo 
  end    

  def total_credits_approved_eq
    academic_records.aprobado.total_credits_equivalence
  end

  def total_credits_approved_without_eq
    academic_records.total_credits_approved_not_equivalence
  end

  def total_credits_by_type_subject tipo
    academic_records.joins(:subject).by_type(tipo).total_credits
  end

  # def credits_approved_by_eq
    # Ojo: Esta función siempre arroja cero porque no pueden existir EI y A, porque son estados direrentes

  #   self.academic_records.aprobado.joins(:subject, :section).equivalencia.sum('subjects.unit_credits')
  # end


  def update_all_efficiency

    Grados.each do |gr| 
      academic_records = gr.academic_records
      cursados = academic_records.total_credits_coursed
      aprobados = academic_records.total_credits_approved

      eficiencia = (cursados and cursados > 0) ? (aprobados.to_f/cursados.to_f).round(4) : 0.0

      aux = academic_records.coursed

      promedio_simple = aux ? aux.round(4) : 0.0

      aux = academic_records.weighted_average
      ponderado = (cursados > 0) ? (aux.to_f/cursados.to_f).round(4) : 0.0
    end

  end

  def calculate_average periods_ids = nil
    if periods_ids
      aux = academic_records.of_periods(periods_ids).promedio
    else
      aux = academic_records.promedio
    end

    (aux and aux.is_a? BigDecimal) ? aux.to_f.round(4) : 0.0

  end

  def get_changed_plain
    self.versions.where("versions.event ILIKE '%Cambio de plan%'")
  end

  # RAILS_ADMIN:
  rails_admin do
    visible false
    navigation_label 'Inscripciones'
    navigation_icon 'fa-solid fa-graduation-cap'

    list do
      search_by :custom_search
      fields :student, :study_plan, :admission_type, :registration_status, :efficiency, :weighted_average, :simple_average
    end

    show do
      fields :student, :enroll_academic_processes, :enabled_enroll_process
      field :numbers
      field :description
    end

    # Update is edit's form
    update do
      # field :study_plan do
      #   partial 'grade/custom_study_plan_id'
      # end
      field :school do
        label 'Escuela'
        render do
          bindings[:view].content_tag(:p, bindings[:object].school.short_name)
        end

      end

      field :study_plan do
        render do
          bindings[:view].render(partial: '/grades/history_plans', locals: {grade: bindings[:object], study_plan: bindings[:object].study_plan, study_plans: bindings[:object].school&.study_plans})
        end
      end      
      
      field :admission_type do
        inline_add false
        inline_edit false
      end

      field :enabled_enroll_process do
        inline_add false
        inline_edit false
      end
      fields :enrollment_status, :current_permanence_status, :registration_status, :graduate_status

      field :start_process do
        inline_edit false
        inline_add false

        render do
          bindings[:view].render(partial: 'rails_admin/main/grade/custom_academic_process_id_field', locals: {schools_auh: bindings[:view]._current_user&.admin&.schools_auh, value: bindings[:object].start_process_id})
        end
        
      end      

      field :appointment_time do
        label 'Fecha y Hora Cita Horaria'
      end
      field :duration_slot_time do 
        label 'Duración Cita Horaria (minutos)'
      end

    end

    # Edit is new's form
    edit do

      field :student do
        render do
          student = Student.where(user_id: bindings[:view].params[:student_id]).first 
          bindings[:view].render(partial: '/grades/custom_student_id', locals: {student: student})
        end
      end

      field :study_plan do
        inline_add false
        inline_edit false
        # render do
        #   bindings[:view].render(partial: '/grades/custom_study_plan_id', locals: {grade: bindings[:object], study_plan: bindings[:object].study_plan, study_plans: bindings[:object].school&.study_plans})
        # end
      end
      field :admission_type do
        inline_add false        
        inline_edit false        
      end
      fields :registration_status, :enrollment_status

      field :start_process do
        inline_edit false
        inline_add false

        render do
          bindings[:view].render(partial: 'rails_admin/main/grade/custom_academic_process_id_field', locals: {schools_auh: bindings[:view]._current_user&.admin&.schools_auh, value: bindings[:object].start_process_id})
        end
        
      end   
    end

    # Update is edit's form
    update do

      field :student do
        render do
          student = Student.where(user_id: bindings[:view].params[:student_id]).first 
          bindings[:view].render(partial: '/grades/custom_student_id', locals: {student: student})
        end
      end

      field :study_plan do
        inline_add false
        inline_edit false
        render do
          bindings[:view].render(partial: '/grades/custom_study_plan_id', locals: {grade: bindings[:object], study_plan: bindings[:object].study_plan, study_plans: bindings[:object].school&.study_plans})
        end
      end
      field :admission_type do
        inline_add false        
        inline_edit false        
      end
      fields :registration_status, :enrollment_status

      field :start_process do
        inline_edit false
        inline_add false

        render do
          bindings[:view].render(partial: 'rails_admin/main/grade/custom_academic_process_id_field', locals: {schools_auh: bindings[:view]._current_user&.admin&.schools_auh, value: bindings[:object].start_process_id})
        end
        
      end
      field :appointment_time do
        label 'Fecha y Hora Cita Horaria'
      end
      field :duration_slot_time do 
        label 'Duración Cita Horaria (minutos)'
      end      
    end    

    export do
      fields :student, :study_plan, :admission_type, :registration_status, :efficiency, :weighted_average, :simple_average, :region
      field :total_subjects_coursed do
        label 'Total Créditos Cursados'
      end
      field :total_subjects_approved do
        label 'Total Créditos Aprobados'
      end      
    end
  end

  private

  def paper_trail_update
    changed_fields = self.changes.keys - ['created_at', 'updated_at']
    if changed_fields.include? 'study_plan_id'
      sp_from = StudyPlan.where(id: self.changes[:study_plan_id]&.first).first
      sp_to = StudyPlan.where(id: self.changes[:study_plan_id]&.second).first
      self.paper_trail_event = "Cambio de plan de #{sp_from&.code} a #{sp_to&.code}"
    else
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡#{object} actualizado en #{changed_fields.to_sentence}"
    end
    
  end  

  def paper_trail_create
    object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
    self.paper_trail_event = "¡Completada inscripción en oferta académica!"
  end  

  def paper_trail_destroy
    object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
    self.paper_trail_event = "¡Registro Académico eliminado!"
  end  

  after_initialize do
    if new_record?
      self.registration_status = :secretaria
    end
  end  

end
