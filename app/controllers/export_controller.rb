class ExportController < ApplicationController
  before_action :logged_as_admin?

  def xls
    if params[:grades_others] and params[:id]
      academic_process = AcademicProcess.find params[:id]
      list = academic_process.invalid_grades_to_csv
      title = "No Validos para Cita Horaria #{academic_process.name}"
    end
    respond_to do |format|
      format.xls {send_data list, filename: "#{title}.xls"}
    end
  end

  def general
    # require 'xlsxtream'
    begin
      # @object = params[:model_name].camelize.constantize.find (params[:id])
      @object = AcademicProcess.find 44 
      
      model = @object.class.name.underscore
      model_titulo = "#{I18n.t("activerecord.models.#{model}.one")&.titleize}"
      aux = "Reporte Coes - Registros - #{model_titulo} #{DateTime.now.strftime('%d-%m-%Y_%I:%M%P')}.csv"
      response.headers.delete('Content-Length')
      response.headers['Cache-Control'] = 'no-cache'
      response.headers['Content-Type'] = "text/event-stream;charset='utf-8';header=present"
      response.headers['X-Accel-Buffering'] = 'no'
      response.headers['ETag'] = '0'
      response.headers['Last-Modified'] = '0'
      response.headers['Content-Disposition'] = "attachment; filename=#{aux}"    


      # io = StringIO.new
      # xlsx = Xlsxtream::Workbook.new(io)
      
      # xlsx.add_worksheet(name: "Registros Académicos de #{model_titulo}") do |sheet|
      #   ActiveRecord::Base.connection.uncached do
      #     @object.academic_records.includes(:section, :user, :period, :subject, :area).find_each(batch_size: 500) do |academic_record|
      #       response.stream.write sheet.add_row(academic_record.valuse_for_report)
      #     end
      #   end
      # end

      response.stream.write %w{CI NOMBRES APELLIDOS ESCUELA CATEDRA ASIGNATURA PERIODO SECCIÓN ESTADO}.join(";")+"\n"
      @object.academic_records.includes(:section, :user, :period, :subject, :area).find_each(batch_size: 500) do |academic_record|
        response.stream.write "#{academic_record.values_for_report.join(';')}\n"
      end

    rescue Exception => e
      flash[:success] = "No se pudo generar el archivo: #{e}" 
      redirect_back fallback_location: '/admin'
    ensure
      response.stream.close
    end
  end  

end
