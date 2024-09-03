# == Schema Information
#
# Table name: departamentos
#
#  id          :string(255)      not null, primary key
#  descripcion :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  escuela_id  :string(255)      not null
#
class Departamento < ApplicationRecord

	# ASOCIACIONES:
	belongs_to :escuela

	has_many :asignaturas
	accepts_nested_attributes_for :asignaturas

	has_many :secciones, through: :asignaturas

	has_many :inscripcionsecciones, through: :secciones#, source: :estudiante

	has_many :profesores
	accepts_nested_attributes_for :profesores

	has_many :administradores
	accepts_nested_attributes_for :administradores

	has_many :catedradepartamentos#, class_name: 'CatedraDepartamento'
	accepts_nested_attributes_for :catedradepartamentos

	has_many :catedras, through: :catedradepartamentos, source: :catedra

	# VALIDACIONES
	validates :id, presence: true, uniqueness: true
	validates :descripcion, presence: true

	# TRIGGERS
	before_save :set_to_upcase

	def descripcion_completa
		"#{self.descripcion.titleize} (#{escuela.descripcion.titleize})"
	end

	protected

	def set_to_upcase
		self.id.strip!
		self.descripcion = self.descripcion.upcase.strip
	end

end
