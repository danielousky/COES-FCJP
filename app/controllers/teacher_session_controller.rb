class TeacherSessionController < ApplicationController
	before_action :set_session_id_if_multirols, only: [:dashboard]
	before_action :authenticate_teacher!

	layout 'logged'

	def dashboard
		if current_user.empty_any_image?
			redirect_to edit_images_user_path(current_user)
		elsif current_user.empty_personal_info?
			redirect_to edit_user_path(current_user)
		end

		@teacher = current_teacher
		@title = "Sessión del Profesor #{@teacher.user_description}"		
	end

end
