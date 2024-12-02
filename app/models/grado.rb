# == Schema Information
#
# Table name: grados
#
#  id                                  :bigint           not null, primary key
#  citahoraria                         :datetime
#  duracion_franja_horaria             :integer
#  eficiencia                          :decimal(4, 2)    not null
#  estado                              :integer          not null
#  estado_inscripcion                  :integer          not null
#  inscrito_ucv                        :integer
#  promedio_ponderado                  :decimal(4, 2)    not null
#  promedio_simple                     :decimal(4, 2)    not null
#  region                              :integer          not null
#  reglamento                          :integer          not null
#  tipo_ingreso                        :integer          not null
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  autorizar_inscripcion_en_periodo_id :string(255)
#  culminacion_periodo_id              :string(255)
#  escuela_id                          :string(255)
#  estudiante_id                       :string(255)
#  iniciado_periodo_id                 :string(255)
#  plan_id                             :string(255)
#  reportepago_id                      :bigint
#
class Grado < ApplicationRecord
	#CONSTANTES:
	TIPO_INGRESOS = ['OPSU', 'OPSU/COLA', 'SIMADI', 'ACTA CONVENIO (DOCENTE)', 'ACTA CONVENIO (ADMIN)', 'ACTA CONVENIO (OBRERO)', 'DISCAPACIDAD', 'DIPLOMATICO', 'COMPONENTE DOCENTE', 'EQUIVALENCIA', 'ART. 25 (CULTURA)', 'ART. 25 (DEPORTE)', 'CAMBIO: 158', 'ART. 6', 'EGRESADO', 'SAMUEL ROBINSON', 'DELTA AMACURO', 'AMAZONAS', 'PRODES', 'CREDENCIALES', 'SIMULTANEOS']


	TITULO_NORMATIVA = "NORMAS SOBRE EL RENDIMIENTO MÍNIMO Y CONDICIONES DE PERMANENCIA DE LOS ALUMNOS EN LA U.C.V"
	ARTICULO7 = 'Artículo 7°. El alumno que, habiéndose reincorporado conforme al artículo anterior, dejare nuevamente de aprobar el 25% de la carga que curse, o en todo caso, el que no apruebe ninguna asignatura durante dos períodos consecutivos, no podrá incorporarse más a la misma Escuela o Facultad, a menos que el Consejo de Facultad, previo estudio del caso, autorice su reincorporación.'

	ARTICULO6 = "Artículo 6°. El alumno que al final del semestre de recuperación no alcance nuevamente a aprobar el 25% de la carga académica que cursa o en todo caso a aprobar por lo menos una asignatura, no podrá reinscribirse en la Universidad Central de Venezuela, en los dos semestres siguientes. Pasados éstos, tendrá el derecho de reincorporarse en la Escuela en la que cursaba sin que puedan exigírsele otros requisitos que los trámites administrativos usuales. Igualmente, podrá inscribirse en otra Escuela diferente con el Informe favorable del Profesor Consejero y de la Unidad de Asesoramiento Académico de la Escuela a la cual pertenecía, y la aprobación por parte del Consejo de Facultad a la cual solicita el traslado. </br></br> Usted ha sido suspendido por dos semestres (un año) y deberá solicitar la reincorporación, según las fechas y los procedimientos establecidos por el Dpto. de Control de Estudios de la FCJP."

	ARTICULO3 = "Artículo 3°. Todo alumno que en un período no apruebe el 25% de la carga académica que curse o que, en todo caso no apruebe por lo menos una asignatura, deberá participar obligatoriamente en el procedimiento especial de recuperación establecido en estas   normas. </br></br> Esto quiere decir que usted puede inscribirse normalmente y debe inscribir la carga mínima permitida por el Plan de Estudios de su Escuela. Usted debe aprobar al menos una asignatura para superar esta sanción. Si usted reprueba nuevamente todas las asignaturas inscritas, será sancionado con el Art. 06, es decir, será suspendido por dos sementres (un año) y deberá solicitar la reincorporación, según las fechas y los procedimientos establecidos por el Dpto. de Control de Estudios de la FCJP."

	# ASOCIACIONES:
	belongs_to :escuela
	belongs_to :estudiante
	has_one :usuario, through: :estudiante
	belongs_to :plan, optional: true, class_name: 'Plan', primary_key: :id
	belongs_to :periodo_ingreso, optional: true, class_name: 'Periodo', foreign_key: :iniciado_periodo_id
	belongs_to :reportepago, optional: true, dependent: :destroy
	belongs_to :autorizar_inscripcion_en_periodo, optional: true, class_name: 'Periodo', foreign_key: :autorizar_inscripcion_en_periodo_id

	has_many :historialplanes, class_name: 'Historialplan'
	has_many :inscripciones, class_name: 'Inscripcionseccion'
	has_many :inscripcionescuelaperiodos
	has_many :periodos, through: :inscripcionescuelaperiodos
	has_many :secciones, through: :inscripciones, source: :seccion
	has_many :asignaturas, through: :secciones

	# CALLBACKS
	before_validation :set_default
	before_save :set_autorizar_inscripcion_en_periodo_id
	after_destroy :destroy_all

	# VALIDACIONES
	validates :tipo_ingreso, presence: true 
	validates :estado_inscripcion, presence: true
	validates_uniqueness_of :estudiante_id, scope: [:escuela_id], message: 'Estudiante ya inscrito en la escuela', field_name: false

	# validates :inscrito_ucv, presence: true 
	# has_many :inscripcionsecciones, foreign_key: [:escuela_id, :estudiante_id]


	# SCOPES

	scope :not_regular?, -> {where "reglamento != 0"}
	scope :no_retirados, -> {where "estado != 3"}
	scope :cursadas, -> {where "estado != 3"}
	scope :aprobadas, -> {where "estado = 1"}
	scope :sin_equivalencias, -> {joins(:seccion).where "secciones.tipo_seccion_id != 'EI' and secciones.tipo_seccion_id != 'EE'"} 
	scope :por_equivalencia, -> {joins(:seccion).where "secciones.tipo_seccion_id = 'EI' or secciones.tipo_seccion_id = 'EE'"}
	scope :por_equivalencia_interna, -> {joins(:seccion).where "secciones.tipo_seccion_id = 'EI'"}
	scope :por_equivalencia_externa, -> {joins(:seccion).where "secciones.tipo_seccion_id = 'EE'"}
	scope :total_creditos_inscritos, -> {joins(:asignatura).sum('asignaturas.creditos')}
	scope :inscritos_ucv, -> {where(inscrito_ucv: true)}
	scope :no_inscritos_ucv, -> {where(inscrito_ucv: false)}

	scope :no_preinscrito, -> {where('estado_inscripcion != 0')}

	scope :culminado_en_periodo, -> (periodo_id) {where "culminacion_periodo_id = ?", periodo_id}
	scope :iniciados_en_periodo, -> (periodo_id) {where "iniciado_periodo_id = ?", periodo_id}
	scope :iniciados_en_periodos, -> (periodo_ids) {where "iniciado_periodo_id IN (?)", periodo_ids}

	scope :de_las_escuelas, lambda {|escuelas_ids| where("grados.escuela_id IN (?)", escuelas_ids)}


	scope :con_inscripciones, -> { where('(SELECT COUNT(*) FROM inscripcionsecciones WHERE inscripcionsecciones.estudiante_id = grados.estudiante_id) > 0') }
	

	# scope :con_cita_horarias, -> { where('(SELECT COUNT(*) FROM citahorarias WHERE citahorarias.estudiante_id = grados.estudiante_id) > 0') }
	scope :con_cita_horarias, -> { where("citahoraria IS NOT NULL")}
	scope :con_cita_horaria_igual_a, -> (dia){ where("date(citahoraria) = '#{dia}'")}
	scope :sin_cita_horarias, -> { where(citahoraria: nil)}

	scope :regular_or_articulo_3, -> {where('reglamento = 0 OR reglamento = 1')}

	scope :con_inscripciones_en_periodo, -> (periodo_id) { joins(inscripciones: :seccion).where('(SELECT COUNT(*) FROM inscripcionsecciones WHERE inscripcionsecciones.estudiante_id = grados.estudiante_id) > 0 and secciones.periodo_id = ?', periodo_id) }

	scope :con_inscripciones_en_periodos, -> (periodo_ids) { joins(inscripciones: :seccion).where("(SELECT COUNT(*) FROM inscripcionsecciones WHERE inscripcionsecciones.estudiante_id = grados.estudiante_id) > 0 and secciones.periodo_id IN (?)", periodo_ids)}
	
	scope :con_inscripciones_en_periodo_2019_mas_otros, -> (periodo_ids) { joins(inscripciones: :seccion).where("(SELECT COUNT(*) FROM inscripcionsecciones WHERE inscripcionsecciones.estudiante_id = grados.estudiante_id) > 0 and secciones.periodo_id = '2019-02A' and secciones.periodo_id IN (?)", periodo_ids)}
	
	# scope :con_inscripcionescuelaperiodos, -> (escuelaperiodo_id) { joins(:inscripcionescuelaperiodos).where('inscripcionescuelaperiodos.escuelaperiodo_id = ?', escuelaperiodo_id) }

	scope :sin_inscripciones, ->{ where('(SELECT COUNT(*) FROM inscripcionsecciones WHERE inscripcionsecciones.estudiante_id = grados.estudiante_id) = 0') }

	scope :sin_plan, -> {where(plan_id: nil)}


	# VARIABLES TIPOS
	enum estado: {cursante: 0, tesista: 1, posible_graduando: 2, graduando: 3, graduado: 4, postgrado: 5}

	enum estado_inscripcion: {preinscrito: 0, confirmado: 1, reincorporado: 2, asignado: 3}
	enum region: [:no_aplica, :amazonas, :barcelona, :barquisimeto, :bolivar, :capital]

	enum reglamento: {regular: 0, articulo3: 1, articulo6: 2, articulo7: 3}
	
	enum tipo_ingreso: TIPO_INGRESOS

	# after_create :enviar_correo_bienvenida

	# def inscripciones
	# 	Inscripcionseccion.joins(:escuela).where("estudiante_id = ? and escuelas.id = ?", estudiante_id, escuela_id)
	# end

	# Así debe ser inscripciones
	# def inscripciones
	# 	Inscripcionseccion.where("estudiante_id = ? and escuelas_id = ?", estudiante_id, escuela_id)
	# end

	# def give_or_update_grade

	# 	unless grade = grado.find_grade
	# 		std = estudiante.find_by_student
	# 		grade = Grade.where(student_id: stud.id)
	# 		if grade&.count.eql? 1
	# 		  grade = grade.first
	# 		  grade.update(study_plan_id: StudyPlan.where(code: plan_id).first.id)
	# 		else
	# 		  grade = grado.find_or_create_grade
	# 		end
	# 	  end

	# end


	def	find_grade
		stud = self.estudiante.find_by_student
		# if self.plan
		# 	plan_id = self.plan_id
		# else
		# 	plan_id = escuela.planes.first&.id
		# end
		if (!stud.nil? and !self.plan_id.nil?)
			Grade.find_by(student_id: stud.id, study_plan_id: StudyPlan.where(code: plan_id))
		end
	end

	def	find_or_initialize_grade
		stud = Student.joins(:user).where('users.ci': self.estudiante_id.gsub(/[^0-9]/, '')).first
		if self.plan
			plan_id = self.plan_id
		else
			plan_id = escuela.planes.first&.id
		end
		if (!stud.nil? and !plan_id.nil?)
			Grade.find_or_initialize_by(student_id: stud.id, study_plan_id: StudyPlan.where(code: plan_id).first.id)
		end
	end

	def	find_or_create_grade
		stud = Student.joins(:user).where('users.ci': self.estudiante_id.gsub(/[^0-9]/, '')).first

		aux_plan_id = self.plan_id,nil? ? escuela.planes.first&.id : self.plan_id

		if (!stud.nil? and !aux_plan_id.nil?)
			aux_grade = Grade.where(student_id: stud.id, study_plan_id: StudyPlan.where(code: aux_plan_id).first.id).first
			admission_type = AdmissionType.where(name: self.tipo_ingreso).first
			aux_grade ||= Grade.create!(student_id: stud.id, study_plan_id: StudyPlan.where(code: aux_plan_id).first.id, current_permanence_status: :regular, admission_type: admission_type )
		end
	end

	
	def importar_grado
		stud = Student.joins(:user).where('users.ci': self.estudiante_id.gsub(/[^0-9]/, '')).first
		if self.plan
			plan_id = self.plan_id
		else
			plan_id = self.escuela.planes.first&.id
		end
		
		if grade = find_or_initialize_grade
			begin

				if grade.new_record?
					if (grade.import_new_grade self)
						'+'
					else
						'x'
					end
				else
					'='
				end

			rescue Exception => e
				
				print_error e
			end


		else
			'Estudiante o Plan no encontrado'
		end		

	end

	def not_regular?
		! self.regular?
	end

	def self.normativa
		TITULO_NORMATIVA
	end

	def normativa_segun_articulo
		if self.articulo_7?
			ARTICULO7
		elsif self.articulo_6?
			ARTICULO6
		elsif self.articulo_3?
			ARTICULO3
		else
			""
		end
	end


	def asignaturas_ofertables_segun_dependencia
		# Buscamos los ids de las asignaturas aprobadas
		aprobadas_ids = self.inscripciones.aprobado.includes(:asignatura).map{|ins| ins.asignatura.id}.uniq

		# Buscamos por ids de las asignaturas que dependen de las aprobadas
		asignaturas_dependientes_ids = Dependencia.where('asignatura_id IN (?)', aprobadas_ids).map{|dep| dep.asignatura_dependiente_id}

		ids_asignaturas_positivas = []

		# Ahora por cada asignatura habilitada miramos sus respectivas dependencias a ver si todas están aprobadas

		asignaturas_dependientes_ids.each do |asig_id|
			ids_aux = Dependencia.where(asignatura_dependiente_id: asig_id).map{|dep| dep.asignatura_id}
			ids_aux.reject!{|id| aprobadas_ids.include? id}
			ids_asignaturas_positivas << asig_id if (ids_aux.eql? []) #Si aprobó todas las dependencias
		end

		# Buscamos las asignaturas sin prelación
		ids_asignaturas_independientes = self.escuela.asignaturas.independientes.ids

		# Sumamos todas las ids ()
		asignaturas_disponibles_ids = ids_asignaturas_positivas + ids_asignaturas_independientes

		Asignatura.where('asignaturas.id IN (?)', asignaturas_disponibles_ids)
	end


	def franja_horaria
		(citahoraria and duracion_franja_horaria) ? citahoraria+duracion_franja_horaria.minutes : nil
		
	end

	def inscripciones_en_periodo_activo
		escupe_activo = escuela.escuelaperiodos.where(periodo_id: escuela.periodo_activo_id).first
		estudiante.inscripcionescuelaperiodos.where(escuelaperiodo_id: escupe_activo.id)
	end

	def inscripto_en_periodo_activo?
		inscripciones_en_periodo_activo.any?
	end

	def autorizar_inscripcion_en_periodo_decrip
		autorizar_inscripcion_en_periodo_id ? autorizar_inscripcion_en_periodo_id : 'Sin Autorización Especial'
	end
	def autorizar_inscripcion_en_periodo_decrip_badge
		"<span class='badge badge-info'>#{autorizar_inscripcion_en_periodo_decrip}</span>".html_safe
	end

	def inscrito_ucv_label
		valor = 'No'
		tipo = 'danger'
		if self.inscrito_ucv
			valor = 'Si'
			tipo = 'success'
		end
		"<span class='badge badge-#{tipo}'>#{valor}</span>".html_safe
	end

	def printHorario periodo_id
	data = Bloquehorario::DIAS
	data.unshift("")
	data.map!{|a| "<b>"+a[0..2]+"</b>"}
	data = [data]

	secciones_ids = secciones.where(periodo_id: periodo_id).ids 
	# bloques = Bloquehorario.where(horario_id: secciones_ids).group(entrada).having('HOUR(entrada)')# intento con Group

	# bloques = Bloquehorario.where(horario_id: secciones_ids).select("HOUR(entrada) AS hora", "bloquehorarios.id AS id").group('hora')# intento con Group
	bloques = Bloquehorario.where(horario_id: secciones_ids).collect{|bh| {horario: bh.dia_con_entrada, id: bh.id}}.uniq{|e| e[:horario] }
	p bloques	

	for i in 7..14 do
		for j in 0..3 do
			# aux = ["#{i.to_s}:#{sprintf("%02i", (j*15))}"]

			# Bloquehorario::DIAS.each do |dia|
			# 	aciertos = bloques.map{|b| b[:id] if b[:horario] == "#{dia} #{Bloquehorario.hora_descripcion "07:00".to_time}"}.compact
				
			# 	aciertos.each do |acierto|

			# 	end
			# 	aux << ""

			# end
			data << ["#{i.to_s}:#{sprintf("%02i", (j*15))}","","","","",""] # En blanco
		end
	end
	return data #bloques
	end

	def descripcion
		"#{estudiante.id}-#{escuela.id}"
	end


	def plan_descripcion_corta
		plan ? plan.descripcion_completa : '--'
	end

	def plan_descripcion
		plan ? plan.descripcion_completa : 'Sin plan asociado'
	end

	def total_creditos_cursados periodos_ids = nil
		if periodos_ids
			inscripciones.total_creditos_cursados_en_periodos periodos_ids
		else
			inscripciones.total_creditos_cursados
		end
	end

	def total_creditos_aprobados periodos_ids = nil
		if periodos_ids
 			inscripciones.total_creditos_aprobados_en_periodos periodos_ids
 		else
 			inscripciones.total_creditos_aprobados
 		end
	end

	def total_creditos
		self.inscripciones.total_creditos
	end

	def update_all_eficiencia

		Grados.each do |gr| 
			inscripciones = gr.inscripciones
			cursados = inscripciones.total_creditos_cursados
			aprobados = inscripciones.total_creditos_aprobados


			eficiencia = (cursados and cursados > 0) ? (aprobados.to_f/cursados.to_f).round(4) : 0.0

			aux = inscripciones.cursadas

			promedio_simple = (promedio aux).round(4)

			aux = inscripciones.ponderado
			ponderado = (cursados > 0) ? (aux.to_f/cursados.to_f).round(4) : 0.0
		end

	end

	def calcular_eficiencia periodos_ids = nil 
        cursados = self.total_creditos_cursados periodos_ids
        aprobados = self.total_creditos_aprobados periodos_ids
		(cursados and cursados > 0) ? (aprobados.to_f/cursados.to_f).round(4) : 0.0
	end

	def calcular_promedio_simple periodos_ids = nil
		if periodos_ids
			aux = inscripciones.de_los_periodos(periodos_ids).cursadas
		else
			aux = inscripciones.cursadas
		end

		(promedio aux).round(4)

	end

	def calcular_promedio_ponderado periodos_ids = nil
		if periodos_ids
			aux = inscripciones.de_los_periodos(periodos_ids).ponderado
		else
			aux = inscripciones.ponderado
		end
		cursados = self.total_creditos_cursados periodos_ids

		(cursados > 0) ? (aux.to_f/cursados.to_f).round(4) : 0.0
	end

	def calcular_promedio_ponderado_aprobado

		aprobados = self.inscripciones.total_creditos_aprobados
		aux = self.inscripciones.ponderado_aprobadas
		(aprobados > 0) ? (aux.to_f/aprobados.to_f).round(4) : 0.0
		
	end

	def promedio aux
		total = aux.count
		if total > 0
			suma = aux.sum(&:calificacion_definitiva)
			(suma.to_f/total.to_f)
		else
			0
		end
	end

	def calcular_promedio_simple_aprobado
		aux = self.inscripciones.aprobadas
		# (aux and aux.count > 0 and !aux.average('calificacion_final').nil?) ? aux.average('calificacion_final').round(4) : 0.0
		(promedio aux).round(4)
	end


	def inscrito_en_periodos? periodo_ids
		(inscripciones.de_los_periodos(periodo_ids)).count > 0
	end



	def inscrito_en_periodo? periodo_id
		(inscripciones.del_periodo(periodo_id)).count > 0
	end

	def ultimo_plan
		aux = plan
		if plan.nil?
			hp = self.historialplanes.por_escuela(escuela_id).order('periodo_id DESC').first	
			aux = hp ? hp.plan : nil
		else
			aux = plan
		end
		return aux 
		# hp = self.historialplanes.por_escuela(escuela_id).order('periodo_id DESC').first
		# hp ? hp.plan : nil
	end

	def descripcion_ultimo_plan
		plan = ultimo_plan
		if plan
			plan.descripcion_completa_con_escuela
		else
			'Sin Plan Asignado'
		end
	end

	def enviar_correo_asignados_opsu_2020(usuario_id, ip)
		# ) if EstudianteMailer.delay.asignados_opsu_2020(self).deliver
		Bitacora.create!(
			descripcion: "Correo de registro de carrera de estudiante: #{self.estudiante_id} enviado.", 
			tipo: Bitacora::CREACION,
			usuario_id: usuario_id,
			comentario: nil,
			id_objeto: self.id,
			tipo_objeto: self.class.name,
			ip_origen: ip
		) if EstudianteMailer.asignados_opsu_2020(self).deliver
	end
	def enviar_correo_bienvenida(usuario_id, ip)
		Bitacora.create!(
			descripcion: "Correo de registro de carrera de estudiante: #{self.estudiante_id} enviado.", 
			tipo: Bitacora::CREACION,
			usuario_id: usuario_id,
			comentario: nil,
			id_objeto: self.id,
			tipo_objeto: self.class.name,
			ip_origen: ip
		) if EstudianteMailer.bienvenida(self).deliver_later
	end

	def enviar_correo_cita_horaria(usuario_id, ip, periodo_id)
		if self.estudiante.usuario.email
			if EstudianteMailer.cita_horaria(self, periodo_id).deliver_later
				Bitacora.create!(
					descripcion: "Correo de citahoraria de estudiante: #{self.estudiante_id} enviado.", 
					tipo: Bitacora::CREACION,
					usuario_id: usuario_id,
					comentario: nil,
					id_objeto: self.id,
					tipo_objeto: self.class.name,
					ip_origen: ip
				)
				return true
			else 
				return false
			end
		else
			return false
		end
	end

	private

	def set_default
		self.region ||= :no_aplica
		self.estado_inscripcion ||= :asignado
	end
	def set_autorizar_inscripcion_en_periodo_id
		self.autorizar_inscripcion_en_periodo_id = nil if self.autorizar_inscripcion_en_periodo_id.eql? ''
	end

	def destroy_all
		destroy_estudiante
		destroy_inscripciones
	end

	def destroy_estudiante
		self.estudiante.destroy unless self.estudiante.grados.any?
	end

	def destroy_inscripciones
		inscripciones.destroy_all
	end
	# def actualizar_estado_inscripciones
	# 	if asignatura.tipoasignatura_id.eql? Tipoasignatura::PROYECTO
	# 		if self.sin_calificar?
	# 			grado.update(estado :tesista)
	# 		elsif self.retirado? or self.aplazado
	# 			grado.update(estado :pregrado)
	# 		elsif self.aprobado?
	# 			grado.update(estado 'posible_graduando')
	# 		end
	# 	end
	# end	


end
