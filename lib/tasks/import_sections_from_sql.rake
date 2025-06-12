namespace :import do
  desc "Importa secciones y asigna teachers desde archivo SQL"
  task sections_from_sql: :environment do
    require 'open-uri'

    file_path = 'https://coesfcjp-space.nyc3.cdn.digitaloceanspaces.com/uxxi_reg_2024_2025%20-%208%20Mayo%202025.sql'
    found_create = false

    # Ajusta estos valores según tu lógica de curso/período
    academic_process = AcademicProcess.find 10
    puts "Usando AcademicProcess: #{academic_process&.process_name || academic_process&.id}"

    URI.open(file_path) do |f|
      f.each_line do |line|
        # Esperar hasta CREATE TABLE `secciones`
        unless found_create
          found_create = true if line =~ /CREATE TABLE `secciones`/i
          next
        end

        # Procesar solo los INSERT INTO `secciones`
        next unless line =~ /INSERT INTO `secciones` VALUES \((.+)\);/i

        data = $1.split(/,(?=(?:[^']*'[^']*')*[^']*$)/).map { |v| v.strip.gsub(/^'|'$/, '') }
        cedula = data[0]
        section_letter = data[2]
        subject_code = data[1]

        teacher_name = data[6]

        last_name, first_name = teacher_name.split(',')
        if cedula.blank? or cedula.upcase.eql? 'NULL' or cedula.strip.empty? 
          puts "Cédula en blanco o NULL!!!! en la línea: #{line.strip}"
          next
        end
        # Buscar teacher por cédula
        teacher = Teacher.joins(:user).where('users.ci': cedula).first
        unless teacher
          puts "Teacher no encontrado: #{cedula} - #{teacher_name}"
          
          if usuario = User.find_by(ci: cedula)
            puts "Usuario ya existe: #{usuario.ci} - #{usuario.first_name} #{usuario.last_name}"
          else
            puts "Creando nuevo usuario para teacher: #{cedula} - #{teacher_name}"
            usuario = User.create!(
              ci: cedula,
              first_name: first_name&.strip,
              last_name: last_name&.strip,
              email: "#{cedula}@mailinator.com",
              password: cedula
            )
          end

          teacher = Teacher.new(user: usuario)
          if teacher.save!(validate: false)
            puts "Nuevo teacher creado: #{teacher.user.ci} - #{teacher.user.first_name} #{teacher.user.last_name}"
          else
            puts "Error creando teacher: #{teacher.errors.full_messages.join(', ')}"
            next
          end
        end

        # Buscar subject
        subject = Subject.where(code: subject_code).or(Subject.where(code: '0#{subject_code}')).first
        unless subject

          puts "Subject no encontrado: (#{subject_code})"
          next
        else
          course = Course.find_or_create_by(
            academic_process_id: academic_process.id,
            subject_id: subject.id
          )
          
          section = Section.find_or_initialize_by(
              course_id: course.id,
              code: section_letter.upcase
          )
          
          section.set_default_values_by_import if section.new_record?
          section.teacher = teacher
          if section.save
            # puts "Section #{section.code} (#{subject.name}) asignada a teacher #{teacher.user.ci}"
            print '.'
          else
            puts "Error guardando section #{section.code}: #{section.errors.full_messages.join(', ')}"
          end
        end
      end
    end
    puts "Importación finalizada."
  end
end