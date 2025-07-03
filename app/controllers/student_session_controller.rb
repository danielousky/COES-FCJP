class StudentSessionController < ApplicationController
	before_action :set_session_id_if_multirols, only: [:dashboard]
	before_action :authenticate_student!

	layout 'logged'
	def dashboard
		# OCULATAMIENTO TEMPORAL DE DATOS PERSONALES:
		if current_user.empty_any_image?
			redirect_to edit_images_user_path(current_user)
		elsif current_user.empty_personal_info?
			redirect_to edit_user_path(current_user)
		elsif current_student.empty_info?
			redirect_to edit_student_path(current_student)
		elsif current_student.address.nil?
			redirect_to new_student_address_path(current_student.id)
		elsif current_student.address.empty_info?
			redirect_to new_student_address_path(current_student.id)
			# redirect_to edit_address_path(current_student)
		end

		@student = current_student

	end
end
