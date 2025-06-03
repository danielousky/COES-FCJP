class StudentsController < ApplicationController
  before_action :set_student, only: [:edit, :update]
  before_action :authenticate_student_or_teacher!

  layout 'logged'

  def update

    p "Updating student with params: #{student_params[:grades_attributes]}".center(80, '=')
    if @student.update(student_params)
      
      flash[:success] = '¡Datos guardados con éxito!'
    else
      flash[:danger] = "Error al intentar guardar los datos: #{@student.errors.full_messages.to_sentence}"
    end
    redirect_to student_session_dashboard_path
  end

  def countries
    country = params[:term]
    data_hash = Student.countries
    render json: data_hash[country].sort{|a,b| a <=> b}, status: :ok
  end

  private

    def set_student
      @student = Student.find(params[:id])
    end

    def student_params
      params.require(:student).permit(
        :disability, :nacionality, :marital_status, :origin_country, :origin_city, :birth_date,
        :grade_title, :grade_university, :graduate_year,
        grades_attributes: [:id, :admission_type_id, :start_process_id]
      )
    end
end
