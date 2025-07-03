class UsersController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :edit ]
  before_action :set_user, only: [:edit, :update, :edit_images, :reset_password]
  # before_action :authenticate_student_or_teacher!

  layout 'logged'
  def edit_images
  end

  # Función para resetear contraseña a un usuario desde Rails Admin
  def reset_password
    @user.password = @user.ci
    @user.password_confirmation = @user.ci

    if @user.update(password: @user.ci, password_confirmation: @user.ci) and @user.update_column(:updated_password, false)
      flash[:success] = "Contraseña reseteada correctamente del usuario."
    else
      flash[:error] = "No se pudo resetear la contraseña del usuario."
    end
    redirect_back fallback_location: rails_admin_path
  end

  def update
    begin
      if @user.update(user_params)
        flash[:success] = '¡Datos guardados con éxito!'
      else
        flash[:danger] = "#{@user.errors.full_messages.to_sentence}"
      end
      
    rescue Exception => e
      e = 'Sin cambios realizados' if e.to_s.include? 'param is missing or the value is empty: user'
      flash[:info] = e
    end
    # back = root_path
    # back = teacher_session_dashboard_path if logged_as_teacher?
    # back =  if logged_as_student?

    if logged_as_admin?
      redirect = rails_admin_path
    elsif @user.teacher?
      redirect = teacher_session_dashboard_path
    elsif @user.student?
      redirect = student_session_dashboard_path
    else 
      redirect = root_path
    end

    redirect_to redirect

  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def user_params

      params.require(:user).permit(:email, :first_name, :last_name, :sex, :number_phone, :ci_image, :profile_picture,:password, :password_confirmation)

    end
end
