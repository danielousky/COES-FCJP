# == Schema Information
#
# Table name: sections
#
#  id         :bigint           not null, primary key
#  capacity   :integer
#  classroom  :string
#  code       :string
#  enabled    :boolean
#  modality   :integer
#  qualified  :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  course_id  :bigint           not null
#  teacher_id :bigint
#
# Indexes
#
#  index_sections_on_code_and_course_id  (code,course_id) UNIQUE
#  index_sections_on_course_id           (course_id)
#  index_sections_on_teacher_id          (teacher_id)
#
# Foreign Keys
#
#  fk_rails_...  (course_id => courses.id)
#  fk_rails_...  (teacher_id => teachers.user_id) ON DELETE => cascade ON UPDATE => cascade
#
class Section < ApplicationRecord
  include Totalizable
  # HISTORY:
  has_paper_trail on: [:create, :destroy, :update]

  before_create :paper_trail_create
  before_destroy :paper_trail_destroy
  before_update :paper_trail_update

  # ASSOCIATIONS:
  # belongs_to
  belongs_to :course
  belongs_to :teacher, optional: true
  has_one :user, through: :teacher

  # has_one
  has_one :subject, through: :course
  has_one :subject_type, through: :subject
  has_one :area, through: :subject
  has_one :departament, through: :subject
  # accepts_nested_attributes_for :subject

  has_one :academic_process, through: :course
  # accepts_nested_attributes_for :academic_process

  has_one :period, through: :academic_process
  has_one :school, through: :academic_process
  has_one :faculty, through: :school

  # has_many
  has_many :schedules, dependent: :destroy
  accepts_nested_attributes_for :schedules, allow_destroy: true

  has_many :academic_records, dependent: :destroy
  # accepts_nested_attributes_for :academic_records

  has_many :enroll_academic_processes, through: :academic_records
  has_many :grades, through: :enroll_academic_processes
  has_many :students, through: :grades

  # has_and_belongs_to_many :teachers#, class_name: 'SectionTeacher', dependent: :delete_all
  has_and_belongs_to_many :secondary_teachers, class_name: 'Teacher'

  has_one :timetable, dependent: :destroy
  accepts_nested_attributes_for :timetable, allow_destroy: true

  has_many :timeblocks, through: :timetable#, dependent: :destroy
  accepts_nested_attributes_for :timeblocks#, allow_destroy: true

  # has_many :secondary_teachers, through: :section_teachers, class_name: 'Teacher'
  # accepts_nested_attributes_for :section_teachers



	# has_many :secciones_profesores_secundarios,
	# 	class_name: 'SeccionProfesorSecundario', dependent: :delete_all
	# accepts_nested_attributes_for :secciones_profesores_secundarios

	# has_many :profesores, through: :secciones_profesores_secundarios, source: :profesor





  # # has_and_belongs_to_namy
  # has_and_belongs_to_many :section_teachers, class_name: 'SectionTeacher'
  # has_and_belongs_to_many :secondary_teachers, through: :section_teachers, class_name: 'Teacher'

  #ENUMERIZE:
  enum modality: {nota_final: 0, equivalencia_externa: 1, equivalencia_interna: 2, suficiencia: 3, reparacion: 4, diferido: 5}

  # VALIDATIONS:
  validates :code, presence: true, uniqueness: { scope: :course_id, message: 'Ya existe la sesión para el curso', case_sensitive: false, field_name: false}, length: { in: 1..7, too_long: "%{count} caracteres es el máximo permitido", too_short: "%{count} caracter es el mínimo permitido"}
  validates :capacity, presence: true
  validates :course, presence: true
  validates :modality, presence: true
  validates :qualified, inclusion: { in: [ true, false ] }

  #CALLBACKS
  # before_save :set_code_to_02i
  after_save :update_academic_records

  
  # SCOPE:
  default_scope {includes(:course, :subject, :period, :area)} # No hace falta
  scope :sort_by_period, -> {joins(:period).order('periods.name')}
  scope :sort_by_period_reverse, -> {joins(:period).order('periods.name DESC')}

  scope :custom_search, -> (keyword) { joins(:period, :subject, :user).where("users.ci ILIKE '%#{keyword}%' OR users.first_name ILIKE '%#{keyword}%' OR users.last_name ILIKE '%#{keyword}%' OR sections.code ILIKE '%#{keyword}%' OR subjects.name ILIKE '%#{keyword}%' OR subjects.code ILIKE '%#{keyword}%' OR periods.name ILIKE '%#{keyword}%'").sort_by_period }
  
  scope :qualified, -> () {where(qualified: true)}

  # Atención: Este scope no esta trabajando
  # scope :codes, -> () {select(:code).all.distinct.order(code: :asc).map{|s| s.code}}
  scope :codes, -> () {all.order(code: :asc).map{|s| s.code}.uniq}

  scope :without_teacher_assigned, -> () {where(teacher_id: nil)}
  scope :with_teacher_assigned, -> () {where('teacher_id IN NOT NULL')}

  scope :has_capacity, -> {joins(:academic_records).group('sections.id').having('count(academic_records.id) < sections.capacity').order('count(academic_records.id)')}

  scope :has_academic_record, -> (academic_record_id) {joins(:academic_records).where('academic_records.id': academic_record_id)}

  scope :not_equivalence, -> {where('sections.modality': [:nota_final, :suficiencia])}
  scope :equivalence, -> {where('sections.modality': [:equivalencia_externa, :equivalencia_interna])}

  # FUNCTIONS:

  def has_teachers?
    !teacher.nil? or secondary_teachers.any?
  end

  def current_user_is_a_teacher_of_this? current_user_id
    has_teachers? and (teacher_id.eql? current_user_id or secondary_teachers.ids.include? current_user_id)
  end
  def self.print_to_system_command
    require 'benchmark'
    memory_command = "ps -o rss= -p #{Process.pid}"
    memory_before = %x(#{memory_command}).to_i
    puts "Memory: #{((memory_before) / 1024.0).round(2)} MB"
  end

  def any_equivalencia?
    self.equivalencia_externa? or  self.equivalencia_interna?
  end

  def label_modality short=false
    if modality
      if short 
        ApplicationController.helpers.label_status_with_tooltip('bg-info', conv_initial_type, modality.titleize)
      else
      ApplicationController.helpers.label_status('bg-info', modality.titleize) 
      end
    end
  end

  def label_qualified
    if self.qualified?
      bg = 'bg-success'
      value = 'Calificada'
    else
      bg = 'bg-secondary'
      value = 'Por Calificar'      
    end
    ApplicationController.helpers.label_status(bg, value)
  end

  def total_students
    self.academic_records.count
  end

  def qualifications_average
    if total_academic_records > 0
      values = academic_records.joins(:qualifications).sum('qualifications.value')
      (values.to_f/total_academic_records.to_f).round(2)
    end
  end

  def excel_list
    require 'spreadsheet'

    @book = Spreadsheet::Workbook.new
    @sheet = @book.create_worksheet :name => "Seccion #{self.name}"


    enrolls = self.academic_records.not_retirado.sort_by_user_name


    @sheet.column(0).width = 15 #estudiantes.collect{|e| e.cal_usuario_ci.length if e.cal_usuario_ci}.max+2;
    @sheet.column(1).width = 50 #estudiantes.collect{|e| e.cal_usuario.apellido_nombre.length if e.cal_usuario.apellido_nombre}.max+2;
    @sheet.column(2).width = 15 #estudiantes.collect{|e| e.cal_usuario.correo_electronico.length if e.cal_usuario.correo_electronico}.max+2;
    @sheet.column(3).width = 40
    @sheet.column(4).width = 20

    @sheet.row(0).concat ["Profesor: #{self.teacher_desc}"]
    @sheet.row(1).concat ["Sección: #{self.name}"]
    @sheet.row(3).concat %w{CI NOMBRES ESTADO CORREO TELÉFONO}

    data = []
    enrolls.each_with_index do |e,i|
      usuario = e.user
      @sheet.row(i+4).concat e.data_to_excel
    end

    file_name = "reporte_seccion_temp"
    return file_name if (@book.write file_name)
  end



  # def own_grades_to_csv

  #   CSV.generate do |csv|
  #     csv << ['Cédula', 'Apellido y Nombre', 'desde', 'hasta', 'Efficiencia', 'Promedio', 'Ponderado']
  #     own_grades_sort_by_appointment.each do |grade|
  #       user = grade.user
  #       csv << [user.ci, user.reverse_name, grade.appointment_from, grade.appointment_to, grade.efficiency, grade.simple_average, grade.weighted_average]
  #     end
  #   end
  # end


  def capacity_vs_enrolls
    # "#{self.capacity} / #{self.total_students}"
    "#{self.total_students} de #{self.capacity}"
  end

  def description_with_quotes
    aux = "[#{self.teacher.user.short_name}]" if self.teacher
    schedule = "#{self.schedule_short_name}" if self.timeblocks
    "#{code} #{aux} - #{schedule} (#{capacity_vs_enrolls})"
  end

  def has_academic_record? academic_record_id
    self.academic_records.where(id: academic_record_id).any?
  end

  def has_capacity?
    self.capacity and (self.capacity > 0) and (self.total_students < self.capacity)
  end

  def set_default_values_by_import
    self.capacity = 50 
    # self.modality =  (self.code.eql? 'U') ? :equivalencia_externa : :nota_final
    self.modality = :nota_final
  end

  def totaly_qualified?
    !academic_records.sin_calificar.any?
  end

  def qualified?
    qualified.eql? true
  end

  def teacher_desc
    teacher ? teacher.description : 'No Asignado'
  end

  def conv_long
    "U#{self.period.period_type.code}"
  end

  def conv_type
    "#{conv_initial_type}#{academic_process&.conv_type}"
  end

  def conv_initial_type
    I18n.t("activerecord.scopes.section."+self.modality)
  end

  def is_in_process_active?
    self.academic_process&.active? 
  end

  def is_inrolling?
    self.academic_process&.enroll? 
  end

  def number_acta
    "#{self.subject.code.upcase}#{self.code.upcase} #{self.academic_process.process_name}"
  end

  def name_to_file
     "#{self.academic_process.process_name}_#{self.subject.code.upcase}_#{self.code.upcase}" if self.course
  end

  def name
     "#{self.course.name}-#{self.description_with_quotes}" if self.course
  end

  def desc_subj_code
    "#{subject.desc} (#{self.code})"
  end

  def subject_desc
    subject&.desc
  end

  def period_name
    period&.name
  end

  def process_name
    academic_process&.process_name
  end

  def schedule_name
    timeblocks.map{|s| s.name}.to_sentence
  end

  def schedule_teacher_desc_short
      aux = ""
      aux += timeblocks.any? ? schedule_short_name : 'Sin Horario Asignado'
      aux += teacher ? " | #{teacher&.user&.reverse_name }" : " | Sin profesor Asignado"
      # aux += classroom.blank? ? " | Sin aula" : " | #{classroom}"
      return aux
  end

  def schedules_short_desc_label
    if timeblocks.any?
      ApplicationController.helpers.label_status_with_tooltip 'bg-info', schedule_short_name, schedule_name
    else
      ApplicationController.helpers.label_status 'bg-secondary', 'Sin Horario'
    end
  end  

  def schedule_short_name
    timeblocks.map{|s| s.short_name}.to_sentence    
  end

  def teacher_desc 
    teacher.user.ci_fullname if (teacher and teacher.user)
  end

  def schedule_table
    timeblocks.each{|s| s.name}.to_sentence
  end

  def timetable_desc_with_link
    if timeblocks.any?
      aux = ApplicationController.helpers.link_to("/admin/section/#{self.id}", class: 'btn btn-sm btn-primary', 'data-bs-toggle': :tooltip, title: 'Editar Horario') do
        '<i class="fa-solid fa-pencil"></i> '.html_safe
      end
      aux += " <div data-bs-toggle='tooltip' title='#{schedule_name}'>#{schedule_name}</div>".html_safe
    else
      ApplicationController.helpers.link_to("/admin/timetable/new?section_id=#{self.id}", class: 'btn btn-sm btn-success', 'data-bs-toggle': :tooltip, title: 'Agregar Horario') do
        "<i class='fa-solid fa-plus'></i>".html_safe
      end
    end
  end


  def self.icon_entity
    'fa-solid fa-list'
  end  

  # RAILS_ADMIN:
  rails_admin do
    navigation_label 'Config Específica'
    navigation_icon 'fa-solid fa-list'
    weight -1

    list do
      sort_by ['periods.name', 'areas.name', 'courses.name', 'subjects.code']
      filters [:school]
      checkboxes false
      search_by :custom_search
      
      # filters [:period, :code, :subject_code]
      # sort_by 'courses.name'
      # field :academic_process do
      #   label 'Período'
      #   column_width 120
      #   pretty_value do
      #     value.academic_process.process_name
      #   end
      # end

      field :school do
        sticky true 
        searchable :name
        sortable :name
        pretty_value do
          value.code
        end           
      end

      field :academic_process do
        label 'Período'
        searchable :name
        sortable :name
        sticky true
        pretty_value do
          value.process_name
        end
      end
      # field :period do
      #   sticky true
      #   label 'Período'
      #   searchable :name
      #   sortable :name
      #   # associated_collection_cache_all false
      #   # associated_collection_scope do
      #   #   # bindings[:object] & bindings[:controller] are available, but not in scope's block!
      #   #   Proc.new { |scope|
      #   #     # scoping all Players currently, let's limit them to the team's league
      #   #     # Be sure to limit if there are a lot of Players and order them by position
      #   #     scope = scope.joins(:period)
      #   #     scope = scope.limit(30) # 'order' does not work here
      #   #   }
      #   # end
      #   pretty_value do
      #     value.name
      #   end
      # end

      field :area do
        sticky true
        sortable :name
        searchable :name
      end

      # field :period_name do
      #   label 'Período'
      #   column_width 100
      #   # searchable 'periods.name'
      #   # filterable 'periods.name'
      #   # sortable 'periods.name'
      #   formatted_value do
      #     bindings[:object].academic_process&.process_name 
      #   end
      # end

      field :subject do
        sticky true
        label 'Asignatura'
        column_width 250
        searchable :code
        filterable :code #'subjects.code'
        sortable :code
        pretty_value do
          value.desc
        end
      end

      field :code do
        sticky true
        label 'Sec'
        filterable false 
        column_width 30
        formatted_value do
          bindings[:view].link_to(bindings[:object].code, "/admin/section/#{bindings[:object].id}") if bindings[:object].present?

        end
      end

      field :modality do
        pretty_value do
          value&.titleize
        end
      end      

      # field :classroom do
      #   filterable false 
      #   sortable false
      # end

      field :teacher_desc do
        label 'Profesor'
        column_width 240
        # searchable ['users.ci', 'users.first_name', 'users.last_name']
        # filterable ['users.ci', 'users.first_name', 'users.last_name']
        # sortable 'users.ci'
        filterable false 
        formatted_value do
          bindings[:view].link_to(bindings[:object].teacher.desc, "/admin/teacher/#{bindings[:object].teacher_id}") if bindings[:object].teacher.present?
        end
      end

      # field :teacher do
      #   column_width 240
      #   associated_collection_cache_all false
      #   associated_collection_scope do
      #     # bindings[:object] & bindings[:controller] are available, but not in scope's block!
      #     Proc.new { |scope|
      #       # scoping all Players currently, let's limit them to the team's league
      #       # Be sure to limit if there are a lot of Players and order them by position
      #       scope = scope.joins(:teacher, :user)
      #       scope = scope.limit(30) # 'order' does not work here
      #     }
      #   end
      #   searchable ['users.ci', 'users.first_name', 'users.last_name']
      #   filterable ['users.ci', 'users.first_name', 'users.last_name']
      #   sortable ['users.ci', 'users.first_name', 'users.last_name']


      # end

      field :timeblocks do
        label 'Horario'
      end

      field :capacity do
        label 'Cupos'
        column_width 40
        sortable 'sections.capacity'
        filterable false 
        pretty_value do
          ApplicationController.helpers.label_status('bg-info', value)
        end        
      end

      field :numery do
        label 'Números'
        column_width 200
        pretty_value do
          bindings[:object].label_numbery_total
        end
      end

      field :qualifications_average do
        label 'Prom'
        pretty_value do
          ApplicationController.helpers.label_status('bg-info', value)
        end
      end

      field :qualified do
        column_width 20
      end

      field :options do
        label 'Opciones'
        visible do
          current_user = bindings[:view]._current_user
          (bindings[:view].current_user&.admin&.authorized_manage? 'Seccion' and bindings[:object].academic_records.any?)
        end
        pretty_value do
          display = ApplicationController.helpers.badge_toggle_section_qualified bindings[:object]
          display += ApplicationController.helpers.btn_toggle_download 'mx-3 btn-success', "/sections/#{bindings[:object].id}.pdf", 'Generar Acta', nil
          display
        end
      end      
      
    end

    show do
      # field :name do
      #   label 'Descripción'
      # end
      # fields :teacher, :academic_records
      # field :schedules do
      #   label 'Horario'
      #   formatted_value do
      #     value.name
      #   end
      # end

      # field :schedule_table do
      #   label 'Horario'
      #   formatted_value do
      #     bindings[:view].render(partial: "schedules/on_table", locals: {schedules: bindings[:object].schedules})
      #   end
      # end

      field :desc_show do
        label 'Descripción'
        formatted_value do
          bindings[:view].render(partial: "sections/show_by_admin", locals: {section: bindings[:object]})
        end
      end

      field :secondary_teachers

      field :academic_records_table do
        label 'Registros Académicos'
        formatted_value do
          current_user = bindings[:view]._current_user
          if bindings[:object].is_in_process_active? and not bindings[:object].is_inrolling? and current_user&.admin&.authorized_manage? 'Section'
            bindings[:view].render(partial: 'academic_records/qualify', locals: {section: bindings[:object]})
          else
            bindings[:view].render(partial: 'academic_records/list', locals: {academic_records: bindings[:object].academic_records, admin: true}) 
          end
        end
      end
    end

    edit do
      field :course do
        inline_edit false
        inline_add true
        # partial 'course/custom_course_id_field'
      end

      field :code do
        html_attributes do
          {:length => 8, :size => 8, :onInput => "$(this).val($(this).val().toUpperCase().replace(/[^A-Za-z0-9]/g,''))"}
        end
      end

      field :modality

      field :teacher do
        label 'Profesor Principal'
        inline_edit false
        inline_add false

        associated_collection_cache_all false
        associated_collection_scope do
          Proc.new { |scope|
            scope = Teacher.all
            scope = scope.limit(10) # 'order' does not work here
          }
        end
      end

      field :secondary_teachers do
        inline_edit false
        inline_add false
      end

      # field :classroom do
      #   html_attributes do
      #     {:onInput => "$(this).val($(this).val().toUpperCase().replace(/[^A-Za-z0-9| ]/g,''))"}
      #   end
      # end

      field :capacity do
        html_attributes do
          {:min => 1}
        end
      end

      field :timetable

    end


    update do
      field :course do
        read_only true
      end
      field :qualified
      
      field :code do
        help 'Identificador'
        html_attributes do
          {:length => 8, :size => 8, :onInput => "$(this).val($(this).val().toUpperCase().replace(/[^A-Za-z0-9]/g,''))"}
        end
      end

      field :modality

      field :teacher do
        label 'Profesor Principal'
        inline_edit false
        inline_add false
      end

      field :secondary_teachers do
        inline_edit false
        inline_add false
      end


      # field :classroom do
      #   html_attributes do
      #     {:onInput => "$(this).val($(this).val().toUpperCase().replace(/[^A-Za-z0-9| ]/g,''))"}
      #   end
      # end

      field :capacity do
        html_attributes do
          {:min => 1}
        end
      end

      field :timetable

    end


    export do
      fields :period, :area, :subject, :code, :classroom, :user, :qualified, :modality, :timeblocks, :capacity

      field :total_students do 
        label 'Total inscritos'
        formatted_value do
          bindings[:object].total_students
        end
      end      

      field :total_sc do
        label 'Sin Calificar'

      end
      field :total_aprobados do
        label 'Total Aprobados'
      end
      field :total_aplazados do
        label 'Total Aplazados'
      end
      field :total_retirados do
        label 'Total Retirados'
      end 
      field :total_pi do
        label 'Total PI'
      end
      field :qualifications_average do
        label 'Promedio de Calificaciones'
      end

    end
  end

  private

  def self.import row, fields

    total_newed = total_updated = 0
    no_registred = nil

    if row[0]
      row[0].strip!
    else
      return [0,0,0]
    end

    if row[1]
      row[1].strip!
      row[1].delete! '^A-Za-z|0-9'
    else
      return [0,0,1]
    end

    subject = Subject.find_by(code: row[1])
    subject ||= Subject.find_by(code: "0#{row[1]}")

    if subject
      # school = School.find (fields[:escuela_id])
      # period = Period.find (fields[:perido_id])
      
      academic_process = AcademicProcess.find fields[:academic_process_id]
      if academic_process
        if curso = Course.find_or_create_by(subject_id: subject.id, academic_process_id: academic_process.id)
          s = Section.find_or_initialize_by(code: row[0], course_id: curso.id)
          nueva = s.new_record?

          s.set_default_values_by_import if nueva

          if row[2]
            row[2].strip!
            row[2].delete! '^0-9'
            s.capacity = row[2]
          end

          if row[3]
            row[3].strip!
            row[3].delete! '^0-9'
            user = User.find_by(ci: row[3])
            s.teacher_id = user.id if user and user.teacher?
          end

          if s.save
            if nueva
              total_newed = 1
            else
              total_updated = 1
            end
          else
            no_registred = 0
          end
        else
          no_registred = 1 
        end
      else
        no_registred = 1
      end
    else
      no_registred = 1
    end
    [total_newed, total_updated, no_registred]
  end

  # def set_code_to_02i
  #   self.code&.upcase!
  #   begin
  #     aux = sprintf("%02i", self.code)
  #     self.code = aux
  #   rescue Exception => e

  #   end
  # end

  def update_academic_records
    if self.any_equivalencia?
      academic_records.each do |ar|
        ar.update(status: :aprobado)
        ar.qualifications.destroy_all  
      end
    end
  end
  
  private

    def paper_trail_update
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      msg = "#{object} actualizada."
      if self.qualified_changed?
        msg = self.qualified? ? "¡Sección calificada!" : "Activada para calificar nuevamente"
      end
      # changed_fields = self.changes.keys - ['created_at', 'updated_at']
      # self.paper_trail_event = "¡#{object} actualizado en #{changed_fields.to_sentence}"
      self.paper_trail_event = msg
    end  

    def paper_trail_create
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡#{object} registrada!"
    end  

    def paper_trail_destroy
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡#{object} eliminada!"
    end
end
