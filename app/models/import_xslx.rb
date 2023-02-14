class ImportXslx

	def self.general_import fields, headers_layout
		require 'simple_xlsx_reader'

		errores_cabeceras = []

		begin
			doc = SimpleXlsxReader.open(fields[:datafile].tempfile)
			hoja = doc.sheets.first

			hoja.rows.shift if hoja.headers.include? nil
			headers = hoja.headers
			rows = hoja.data

			p "        HEADERS: #{headers}       ".center(300, "-")
			p "        ROWS: #{rows}       ".center(300, "-")

			# headers = rows.shift 
			# temp = headers.first
			# headers = rows.shift unless (temp.include? 'id' or temp.include? 'ci' or temp.include? 'numero')

			# rows = hoja.data#.rows#.group_by{|row| row[0]}.values

			headers.compact!
			# if headers = headers.map(&:downcase)		 
			# 	headers_layout.each do |head| 
			# 		errores_cabeceras << "Falta la cabecera '#{head}' en el archivo o está mal escrita" unless headers.include? head	
			# 	end
			# else
			# 	errores_cabeceras << "La cabecera del archivo no se encuentra. Por favor genere nuevamente el archivo." 
			# end

		rescue Exception => e
			errores_cabeceras << "Error al intentar abrir el archivo: #{e}"
		end


		if errores_cabeceras.any?
			errores_cabeceras << headers
			return [0,0, errores_cabeceras]
		else		
			errors = []
			error_type = 1
			total_newed = 0
			total_updated = 0
			resumen = ""
			row_record = ''
			row_index = 0

			begin
				# rows.shift

				rows.each_with_index do |row, i|
					row_record = row
					row_index = i
					p "      STEP: #{i}, #{row}".center(1000, "=")
					sum_newed, sum_updated, sum_errors = fields[:entity].singularize.camelize.constantize.import row, fields
					unless sum_errors.blank?
						sum_errors = "#{(65+sum_errors).chr}" if sum_errors.is_a? Integer and sum_errors >= 0 and sum_errors < 6
						errors << "#{i+1}:#{sum_errors}"
					end
					total_newed += sum_newed
					total_updated += sum_updated

					p "      ERROR: #{sum_errors}     ".center(900, "-")
					
					break if errors.count > 100
				end

			rescue Exception => e
				errors << "Fila #{row_index} #{e} "
			end

			return [total_newed, total_updated, errors.uniq]
		end

	end

end