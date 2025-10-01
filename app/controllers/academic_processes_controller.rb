class AcademicProcessesController < ApplicationController
  before_action :set_academic_process, only: %i[ show edit update destroy clone_sections clean_courses run_regulation massive_confirmation massive_actas_generation massive_delete_unreported]

  def massive_confirmation
    total = @academic_process.enroll_academic_processes.not_confirmado.with_payment_report
    total_count = total.count
    begin
      total.each {|ins| ins.confirm_with_email}
      flash[:success] = "Se actualizaron #{total_count} inscripciones"
    rescue Exception => e
      flash[:danger] = "No fue posible completar la operación: #{e}"
    end
    redirect_back fallback_location: '/admin/enroll_academic_process'
  end

  def massive_delete_unreported
    total = @academic_process.enroll_academic_processes.not_confirmado.sin_reporte_de_pago.limit(50)
    total_count = total.count

    if total.destroy_all
      # Registrar la actividad en PaperTrail para el usuario actual
      if current_user
        PaperTrail.request(whodunnit: current_user.id) do
          @academic_process.paper_trail_event = "Eliminación masiva de inscripciones sin reporte de pago por el usuario #{current_user.email}"
          @academic_process.save(validate: false)
        end
      end
      flash[:info] = "Fueron eliminadas #{total_count} inscripciones"
    else
      flash[:danger] = "No fue posible completar la operación: #{e}"
    end
    redirect_back fallback_location: '/admin/enroll_academic_process'
  end

  def massive_actas_generation

    sections = @academic_process.sections.qualified
    pdf = CombinePDF.new

    sections.each do |section|

      footer_html = view_context.render template: "/sections/signatures", locals: {teacher: section.teacher&.user&.acte_name}
      header_html = view_context.render template: "/sections/acta_header", locals: {school: section.school, section: section}

      pdf << CombinePDF.parse(render_to_string(delete_temporary_files: true, pdf: 'actas_sections', 
      template: "sections/acta", page_size: 'letter', margin: {top: 72, bottom: 68},
      locals: {section: section}, formats: [:html],
      footer: {content: footer_html},
      header: {content: header_html}))
    end
    send_data pdf.to_pdf, filename: "Total Actas Periodo #{@academic_process.name}.pdf", type: "application/pdf", disposition: :attachment #:inline
  end


  # def massive_actas_generation_alt
  #   sections = @academic_process.sections.qualified
  #   pdf = CombinePDF.new
  #   aux = "Actas_secciones_periodo_#{@academic_process.name}.pdf"
  #   response.headers.delete('Content-Length')
  #   response.headers['Cache-Control'] = 'no-cache'
  #   response.headers['Content-Type'] = "pdf/event-stream;charset='utf-8';header=present"
  #   response.headers['X-Accel-Buffering'] = 'no'
  #   response.headers['ETag'] = '0'
  #   response.headers['Last-Modified'] = '0'
  #   response.headers['Content-Disposition'] = "attachment; filename=#{aux}"    

  #   sections.each do |section|
  #     pdf_data = render_to_string pdf: "acta_#{section.number_acta}", template: "sections/acta", locals: {section: section}, formats: [:html], page_size: 'letter', header: {html: {template: '/sections/acta_header', formats: [:html], layout: false, locals: {school: section.school, section: section}}}, footer: {html: {template: '/sections/signatures', formats: [:html], locals: {teacher: section.teacher&.user&.acte_name}}}, margin: {top: 72, bottom: 68}#, dpi: 150
  #     response.stream.write pdf_data
      
  #   end
  # ensure
  #   response.stream.close
  # end


  def run_regulation
    total_actualizados = 0
    total_error = 0
    @academic_process.school.enrollment_days.each{|ed| ed.destroy}
    @academic_process.enroll_academic_processes.each do |iep|

      grade = iep.grade
      
      if iep.is_the_last_enroll_of_grade?
        
        iep.update(permanence_status: iep.get_regulation)
        iep.reload
        if grade.update(appointment_time: nil, duration_slot_time: nil, current_permanence_status: iep.permanence_status, efficiency: grade.calculate_efficiency, weighted_average: grade.calculate_weighted_average, simple_average: grade.calculate_average) and iep.update(efficiency: iep.calculate_efficiency, simple_average: iep.calculate_average, weighted_average: iep.calculate_weighted_average)
          total_actualizados += 1
        else
          total_error += 1
        end
      else
        if grade.update(efficiency: grade.calculate_efficiency, weighted_average: grade.calculate_weighted_average, simple_average: grade.calculate_average)
          total_actualizados += 1
        else
          total_error += 1
        end
      end        
    end
    
    flash[:danger] = "#{ total_error} #{'Error'.pluralize(total_error)} en la actualización del estado de reglamento" if total_error > 0 
    flash[:success] = "#{ total_actualizados} #{'inscripción'.pluralize(total_actualizados)} en total actualizados" if total_actualizados > 0
    
    redirect_back fallback_location: "/admin/academic_process/#{params[:id_return]}/enrollment_day"
  end


  # GET /academic_processes or /academic_processes.json
  def index
    @academic_processes = AcademicProcess.all
  end

  # GET /academic_processes/1 or /academic_processes/1.json
  def show
  end

  # GET /academic_processes/new
  def new
    @academic_process = AcademicProcess.new
  end

  # GET /academic_processes/1/edit
  def edit
  end

  # def change_process_session
  #   session[:academic_process_id] = params[:id]
  #   redirect_back fallback_location: root_path
  # end

  def clean_courses
    total = @academic_process.courses.count
    if @academic_process.courses.destroy_all
      flash[:info] = "Eliminados #{total} cursos con sus respectivas secciones."
    else
      flash[:danger] = "No se pudieron eliminar los cursos."
    end

    redirect_back fallback_location: root_path
  end

  def clone_sections
    if @academic_process.enroll_academic_processes.any?
      flash[:denger] = 'No se puede clonar un processo con registro académicos. Primero limpie el proceso académico y luego procesa a clonarlo.'
    else
      cloneble_academic_process = AcademicProcess.find params[:cloneble_academic_process_id]
      errors = 0
      completed = 0

      @academic_process.courses.destroy_all
      begin
        cloneble_academic_process.courses.each do |course|
          nuevo_curso = course.dup
          nuevo_curso.academic_process_id = @academic_process.id
          if nuevo_curso.save
            course.sections.each do |section|
              nueva_seccion = section.dup
              nueva_seccion.course_id = nuevo_curso.id
              nueva_seccion.teacher_id = nil unless params[:teachers]
              nueva_seccion.qualified = false
              if nueva_seccion.save
                if params[:schedules] and section.timetable
                  tt_aux = section.timetable.dup
                  tt_aux.section_id = nueva_seccion.id
                  if tt_aux.save(validate: false)
                    section.timetable.timeblocks.each do |tb|
                      tb_aux = tb.dup
                      tb_aux.timetable_id = tt_aux.id
                      tb_aux.save
                    end
                  end
                end
                completed +=1
              else
                errors += 1
              end
            end
          else
            errors += 1
          end
        end
      rescue Exception => e
        flash[:danger] = e
      end  
      flash[:danger] = "#{errors} Cargas con errores. Vuelva a intentarlo." if errors > 0
      if completed > 0
        flash[:success] = "Clonación de #{completed} secciones." 
        flash[:success] += " Incluida clonación de Inscrucciones de Inscripción" if @academic_process.update(enroll_instructions: cloneble_academic_process.enroll_instructions)
      end

    end

    redirect_back fallback_location: root_path

  end



  # POST /academic_processes or /academic_processes.json
  def create
    @academic_process = AcademicProcess.new(academic_process_params)

    respond_to do |format|
      if @academic_process.save
        format.html { redirect_to academic_process_url(@academic_process), notice: "Academic process was successfully created." }
        format.json { render :show, status: :created, location: @academic_process }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @academic_process.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /academic_processes/1 or /academic_processes/1.json
  def update
    respond_to do |format|
      if @academic_process.update(academic_process_params)
        # format.json { render json: '¡Escuela actualizada con éxito!', status: :ok}
        format.json {render json: {data: '¡Período actualizado con éxito!', status: :success} }
        format.html { redirect_back fallback_location: root_path, notice: '¡Período actualizado con Éxito!' }
      else
        format.json { render json: {data: @school.errors, status: :unprocessable_entity} }
        format.html { redirect_back fallback_location: root_path, notice: 'No fue posible realizar la solicitud!'  }
      end
    end
  end

  # DELETE /academic_processes/1 or /academic_processes/1.json
  def destroy
    @academic_process.destroy

    respond_to do |format|
      format.html { redirect_to academic_processes_url, notice: "Academic process was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_academic_process
      @academic_process = AcademicProcess.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def academic_process_params
      params.require(:academic_process).permit(:school_id, :period_id, :max_credits, :max_subjects, :active, :enroll, :post_qualification, :payments_active)
    end
end
