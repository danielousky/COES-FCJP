class TimetablesController < ApplicationController
  before_action :set_viewable, only: [:show]

  layout 'logged'
  
  def show

    @days = Timeblock.days.keys
    @start_hour = Timeblock::ALLOWED_START #7 # 7 AM
    @end_hour = Timeblock::ALLWOED_END #21  # 9 PM
    
    case @viewable_type
    when 'Teacher'
      @teacher = Teacher.find(params[:id])
      # @academic_process = @teacher.school.academic_processes.actives.or(@teacher.school.academic_processes.enrolls).first
      @academic_process = AcademicProcess.find(params[:academic_process_id]) if params[:academic_process_id].present?

      @timeblocks = @teacher.timeblocks.joins(:timetable => {:section => {:course => :academic_process}})
                            .where("academic_processes.id": @academic_process.id)
      @title = "Horario del Profesor #{@teacher.user_description} en #{@academic_process.short_desc}" if @academic_process
    when 'EnrollAcademicProcess'
      @timeblocks = Timeblock.joins(:timetable => {:section => {:academic_records => :enroll_academic_process} })
                            .where(enroll_academic_processes: {id: params[:id]})
      @enroll_academic_process = EnrollAcademicProcess.find(params[:id])
      @academic_process = @enroll_academic_process.academic_process
      @title = "Horario Semanal de #{@enroll_academic_process.user&.first_name} en #{@academic_process.short_desc}"

    when 'Course'
      @course = Course.find(params[:id])
      @academic_process = @course.academic_process
      @timeblocks = Timeblock.joins(timetable: {section: :course}).where(courses: {id: @course.id})
      @title = "Horario del Curso: #{@course.subject_desc} (#{@academic_process.short_desc})"

    when 'Section'
      @section = Section.find(params[:id])
      @academic_process = @section.academic_process
      @timeblocks = Timeblock.joins(:timetable).where(timetables: {section_id: @section.id})
      @title = "Horario de la Sección: #{@section.name}"
    else
    #   @timeblocks = Timeblock.all.limit(50)
    #   @title = "Todos los Horarios"
      flash[:alert] = "Sin tipo de vista especificado."
      redirect_back fallback_location: root_path
    end
    
    @time_slots = build_time_slots(@timeblocks)
  end
  
  private
  
  def set_viewable
    @viewable_type = params[:type] || 'All'
  end
  
  def build_time_slots(timeblocks)
    slots = {}
    
    timeblocks.each do |block|
      day = block.day
      start_time = block.start_time.strftime("%H:%M")
      end_time = block.end_time.strftime("%H:%M")
      
      slots[day] ||= {}
      slots[day][start_time] ||= []
      
      timetable = block.timetable
      section = timetable.section
      
      slots[day][start_time] << {
        id: block.id,
        academic_process: section.academic_process&.short_desc,
        title: section.subject_desc,
        subject_code: section.subject.code, 
        section_code: section.code,
        teacher: section.teacher&.user&.reverse_name || "Sin profesor",
        classroom: block.classroom || section.classroom || "Sin aula",
        start_time: start_time,
        end_time: end_time,
        modality: block.modality&.titleize,
        color: timetable.color || "rgba(200,200,200,0.3)",
        timetable_id: timetable.id
      }
    end
    
    slots
  end
end