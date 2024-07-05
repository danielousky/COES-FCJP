# == Schema Information
#
# Table name: profesores
#
#  departamento_id :string(255)
#  usuario_id      :string(255)      not null, primary key
#
class Profesor < ApplicationRecord
    self.table_name = 'profesores'
    self.primary_key = :usuario_id
    # ASOCIACIONES:
	belongs_to :departamento
	accepts_nested_attributes_for :departamento

    has_one :escuela, through: :departamento

	belongs_to :usuario, foreign_key: :usuario_id 
	accepts_nested_attributes_for :usuario

	has_many :secciones, dependent: :nullify
	# accepts_nested_attributes_for :secciones

    has_many :profesor_secciones_secundarias,
        :class_name => 'SeccionProfesorSecundario',
        :foreign_key => :profesor_id

    accepts_nested_attributes_for :profesor_secciones_secundarias

    has_many :secciones_secundarias, through: :profesor_secciones_secundarias, source: :seccion

    has_many :bloquehorarios

    # VALIDACIONES:
    validates :usuario_id, presence: true, uniqueness: true

    # FUNCIONES:
    def find_teacher
        Teacher.joins(:user).where('user.ci': usuario_id).first
    end

    def descripcion
        "#{usuario.descripcion} - #{departamento.descripcion if departamento}"
    end

    def descripcion_apellido
        "#{usuario.descripcion_apellido} - #{departamento.descripcion if departamento}"        
    end

    def descripcion_usuario
        if usuario
            return usuario.descripcion
        else
            "Profesor Sin descripcion"
        end
    end

end
