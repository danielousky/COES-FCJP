namespace :import do
  desc "Importa datos desde archivo SQL"
  task sql_data: :environment do
    # Correr antes la tarea: rake import:sections_from_sql
    require 'open-uri'
    require 'i18n'

    file_path = 'https://coesfcjp-space.nyc3.cdn.digitaloceanspaces.com/uxxi_reg_2024_2025_28_julio_2025.sql'
    table_name = nil
    columns = []
    values = []

  
  total_no_inscritos = 0
  total_asignaturas_no_encontradas = 0
  total_estudiantes_encontrados = 0
  total_grados_no_encontrados = 0

  # Busco el AcademicProcess
  # Atención: El AcademicProcess está seteado a 10. Para estudios políticos debe ser diferente 
  
  puts "Ingrese el ID del AcademicProcess a utilizar:"
  # ap = AcademicProcess.find(10)
  ap_id = STDIN.gets.chomp.to_i
  ap = AcademicProcess.find(ap_id)

  # Busco el Plan de Estudio
  # Atención: Del mismo modo que el AcademicProcess, el Plan de Estudio debe ser diferente para estudios políticos
  # plan = StudyPlan.where(code: 'D002').first
  puts "Ingrese el código del StudyPlan a utilizar:"
  plan_code = STDIN.gets.chomp
  plan = StudyPlan.where(code: plan_code).first

  URI.open(file_path) do |f|
    f.each_line do |line|
      # Detectar nombre de tabla y columnas
      if line =~ /CREATE TABLE `(\w+)`/
        table_name = $1
      elsif line =~ /INSERT INTO `(\w+)` VALUES \((.+)\);/
        table = $1
        data = $2.split(/,(?=(?:[^']*'[^']*')*[^']*$)/).map { |v| v.strip.gsub(/^'|'$/, '') }
        # Aquí debes mapear los datos a tus modelos
        if table =~ /^(.+)_([a-z])$/
          subject_raw = $1
          section_letter = $2
          subject_name = subject_raw.humanize.squish
          section_number = ('a'..'z').to_a.index(section_letter.downcase) + 1

          # Buscar el Subject por nombre
          subject = Subject.where('lower(name) = ?', subject_name.downcase).first

          # Si no lo encuentra, intenta con variantes con acentos
          if subject.nil?
            # Buscar entre todos los Subjects por similitud usando transliterate
            subject = Subject.all.find do |s|
            I18n.transliterate(s.name.to_s.downcase) == I18n.transliterate(subject_name.downcase)
            end
          end

          if subject
            # puts "Materia: #{subject.name} | Sección: #{section_number}- #{section_letter.upcase}"

            course = Course.find_or_create_by(
              academic_process_id: ap.id,
              subject_id: subject.id
            )
            
            section = Section.find_or_initialize_by(
                course_id: course.id,
                code: section_letter.upcase
            )

            if section.new_record?
              section.set_default_values_by_import
              if !section.save
                print "X"
                p "Error al guardar la sección: #{section.errors.full_messages.to_sentence}"
              end
            end

            cedula = data[0]

            # Encontrar Estudiante por CI
            student = Student.joins(:user).where('users.ci': cedula).first
            if student.nil?
              # Si no se encuentra, buscar por nombre
              student = Student.joins(:user).where('lower(users.first_name) = ? AND lower(users.last_name) = ?', data[1].downcase, data[2].downcase).first
            end

            if student.nil?
              total_estudiantes_encontrados += 1
              p "Estudiante no encontrado: #{cedula} - #{data[1]} - #{data[2]}"
              next
            else

              # Busco el Grado
              grade = student.grades.where(study_plan_id: plan.id, student_id: student.id).first

              if grade.nil?
                total_grados_no_encontrados += 1
                p "Grado no encontrado: #{cedula} - #{data[1]} - #{data[2]}"
                next
              end

              # Si se encuentra, inscribir en el AcademicProcess
              enroll_academic_process = EnrollAcademicProcess.find_or_initialize_by(academic_process_id: ap.id, grade_id: grade.id)

              enroll_academic_process.set_default_values_by_import if enroll_academic_process.new_record?

              if enroll_academic_process.save
                academic_record = AcademicRecord.find_or_create_by(
                  enroll_academic_process_id: enroll_academic_process.id,
                  section_id: section.id)

                if academic_record.persisted?
                  if academic_record.new_record?
                      print "NewAR √"
                  end

                  # register_partial_qualification(academic_record, :primer_lapso, data[3])
                  # register_partial_qualification(academic_record, :segundo_lapso, data[4])

                else
                  p "No se pudo guardar AcademicRecord para: #{student.user.ci} - #{subject.name} - #{section_letter.upcase}: #{academic_record.errors.full_messages.to_sentence}"
                end

              else
                total_no_inscritos += 1
                p "Error al guardar la inscripción: #{enroll_academic_process.errors.full_messages.to_sentence}"
                next
              end

            end

          else
            total_asignaturas_no_encontradas += 1
            puts "Materia no encontrada: #{subject_name}"
          end
          

        end        
        # Ejemplo para tabla contratos_y_garantias_a:				
        if false #table == 'contratos_y_garantias_a'
          cedula = data[0]
          nombres = data[1]
          estatus = data[2]
          
          p "Importando: #{cedula} - #{nombres} - #{estatus}"
          # ...otros campos...
          # Aquí puedes crear o actualizar tus modelos:
          # Estudiante.create!(cedula: cedula, nombre: nombres, ...)
        end

      end
    end
  end
  p "Total no encontrados: #{total_no_encontrados}"
    puts "Importación finalizada"
  end


    def self.register_partial_qualification(academic_record, partial, value)

        begin

          if value != 'NULL' && value != ''
              value.gsub!(/[^0-9A-Za-z]/, '')
              value.upcase!
              if value.eql? 'PI'
                  academic_record.update(status: :perdida_por_inasistencia)
              elsif value.eql? 'NP' or value.eql? 'NO'
                  academic_record.update(status: :no_presento)
              elsif value.eql? 'NA'
                  academic_record.update(status: :aplazado)
              elsif value.eql? 'AP':
                  academic_record.update(status: :aprobado)
              elsif value.eql? 'RE'
                  academic_record.update(status: :retirado)
              else
                  if academic_record.partial_qualifications.where(partial: partial).exists?
                      academic_record.partial_qualifications.where(partial: partial).update(value: value)
                  else  
                    academic_record.partial_qualifications.create!(partial: partial, value: value) 
                  end
              end
          end
        rescue => e
          p "Error en PQ: #{e.message}: #{value} - #{partial} - #{academic_record.id}"

        end          
    end

end