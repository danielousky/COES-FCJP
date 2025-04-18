# == Schema Information
#
# Table name: departaments
#
#  id         :bigint           not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  school_id  :bigint           not null
#
# Indexes
#
#  index_departaments_on_school_id  (school_id)
#
# Foreign Keys
#
#  fk_rails_...  (school_id => schools.id)
#
class Departament < ApplicationRecord
	# ASSOCIATIONS:
	belongs_to :school
	has_and_belongs_to_many :areas
	# has_many :areas#, dependent: :restrict_with_error
	has_many :subjects
	has_many :teachers, dependent: :restrict_with_error
	has_many :courses, through: :subjects
	has_many :sections, through: :courses
	has_many :academic_records, through: :sections
	
	has_many :env_auths, as: :env_authorizable, dependent: :destroy

	# VALIDATIONS:
	validates :name, presence: true#, uniqueness: {case_sensitive: false}

	validates_uniqueness_of :name, scope: [:school_id], message: 'Ya se tiene un departamento con ese nombre para la escuela', field_name: false, case_sensitive: false

	validates :school, presence: true

	default_scope { order(name: :asc) }

	before_save {name.strip!}

	def total_sections_by_process process_id
		sections.joins(:course).where('courses.academic_process_id': process_id).count
	end

	def total_section_by_process_and_name process_id
		"#{name} - #{total_sections_by_process process_id}"
	end
	def short_name
		desc
	end
	def desc
		"#{name} (#{school&.code})"
	end

	def full_description
		"#{name} - #{school&.name}"
	end

	def areas_sort
		areas.order(:name)
	end

	rails_admin do
		visible do
			bindings[:controller].current_user&.admin&.authorized_read? 'Subject'
		end

		navigation_label 'Config General'
		navigation_icon 'fa-regular fa-landmark-dome'
		weight 0

		edit do
			field :school do
				inline_edit false
				inline_add false
				partial 'school/custom_school_id_field'
			end
			field :name do
				html_attributes do
					{:onInput => "$(this).val($(this).val().toUpperCase())"}
				end				
			end
		end

		update do

			field :school do
				inline_edit false
				inline_add false
				read_only true
			end
			field :name do
				html_attributes do
					{:onInput => "$(this).val($(this).val().toUpperCase())"}
				end				
			end			
			# field :areas do
			# 	inline_add false
			# end
		end

		list do
			checkboxes false
			sort_by :name
			field :school do
				pretty_value do
					value.short_name
				end
			end

			fields :name, :areas
		end

		show do
			field :full_description do
				label 'Descripción'
			end
			
			field :areas do
				pretty_value do
					bindings[:view].render(template: '/areas/index', locals: {areas: bindings[:object].areas.order(name: :asc)})
				end
			end

			field :teachers do
				pretty_value do
					bindings[:view].render(template: '/teachers/index', locals: {teachers: bindings[:object].teachers})
				end
			end
		end
	end

end
