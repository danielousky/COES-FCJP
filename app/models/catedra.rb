# == Schema Information
#
# Table name: catedras
#
#  id          :string(255)      not null, primary key
#  descripcion :string(255)
#  orden       :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Catedra < ApplicationRecord

	# ASOCIACIONES:
	has_many :asignaturas

	has_many :secciones, through: :asignaturas
	# has_many :programaciones, through: :asignaturas

	has_many :inscripcionsecciones, through: :secciones

	has_many :catedradepartamentos#, class_name: 'CatedraDepartamento'
	accepts_nested_attributes_for :catedradepartamentos

	has_many :departamentos, through: :catedradepartamentos, source: :departamento

	# VALIDAIONES:
	validates :id, presence: true, uniqueness: true
	validates :descripcion, presence: true
	# validates :orden, presence: true

	# TRIGGERS
	before_save :set_to_upcase

	def	find_area
		aux = Area.where(name: self.descripcion).first

		aux ? aux : Area.where(name: "#{self.descripcion} (#{self.id})").first

	end

	def descripcion_completa
		"#{self.descripcion.titleize}"
	end

	protected

	def set_to_upcase
		self.descripcion = self.descripcion.upcase
	end
end
