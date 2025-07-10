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
			headers.compact!

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
				rows.each_with_index do |row, i|
					row_record = row
					row_index = i

					sum_newed, sum_updated, sum_errors = fields[:entity].singularize.camelize.constantize.import row, fields
					unless sum_errors.blank?
						sum_errors = "#{(65+sum_errors).chr}" if sum_errors.is_a? Integer and sum_errors >= 0 and sum_errors < 6
						errors << "#{i+2}:#{sum_errors}"
					end
					total_newed += sum_newed
					total_updated += sum_updated
					
					break if errors.count > 20
					if i >= fields[:limit].to_i
						errors << 'limit_records'
						break
					end
				end

			rescue Exception => e
				errors << "Fila #{row_index} #{e} "
			end

			return [total_newed, total_updated, errors.uniq]
		end

	end

end