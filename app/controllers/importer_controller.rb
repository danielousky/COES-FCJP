class ImporterController < ApplicationController
	def entities
		case params[:entity]
		when 'subjects'	
			require_fields = ['id', 'nombre']
		when 'students', 'teachers'
			require_fields = ['ci', 'email', 'nombres', 'apellidos'] 
		when 'sections'
			require_fields = ['numero', 'codigo', 'capacidad', 'profesor_ci'] 
		when 'academic_records'
			require_fields = ['ci', 'codigo', 'seccion'] 
		end
	
		if require_fields and params[:entity]
			begin			
				result = ImportXslx.general_import params, require_fields


				total = result[0]+result[1]+result[2].count
				flash[:success] = "<b>#{total} Registros Procesados: </b>"
				flash[:success] += "#{result[0]}"+ " Nuevo".pluralize(result[0]) + " | "
				flash[:success] += "#{result[1]}"+ " Actualizado".pluralize(result[1])
				

				if result[2].include? 'limit_records'
					result[2].delete 'limit_records'
					flash[:success] += " | 1 advertencia"

					flash[:warning] = "¡El archivo contiene más de 500 registros! Se procesaron estos primeros 500 y quedaron pendientes el resto. Por favor, divida el archivo y realice una nueva carga. ".html_safe
				end
				
				if result[2].any? 
					flash[:success] += " | #{result[2].count}"+ " con errores."
					flash[:danger] = ""					
					
					flash[:danger] += "Al menos #{result[2].count} registros tienen problemas, no se continuó el proceso de carga. Se muestran los primeros 10".html_safe
					# Generar tabla HTML de errores
					flash[:danger] += errors_table_html(result[2].take(10))
					redirect_back fallback_location: root_path
					
					# else
					# flash[:danger] = " Muchos registros con problemas. Se procede a generar un archivo con los mismos. "
					# model_titulo = "#{I18n.t("activerecord.models.#{params[:entity].singularize}.one")&.titleize}"
					# filename = "Reporte Coes: #{model_titulo} #{I18n.l(Time.now, format: '%F-%H:%M:%S')}.xlsx"

					# file = ImportXslxErrorExporter.export(result[2], filename)

					# # send_data file, filename: filename, disposition: 'inline', type: "application/xlsx",
					# send_file filename, disposition: 'inline', type: "application/xlsx"

				else
					redirect_to "/admin/#{params[:entity].singularize}"
				end
			rescue Exception => e
				flash[:danger] = "Error General: #{e}"
				redirect_back fallback_location: root_path
			end
		else
			flash[:danger] = 'Tipo de entidad no encontrada. Por favor inténtelo nuevamente.'
			redirect_back fallback_location: root_path
		end
	end

	private

	# Convierte los errores en una tabla HTML
	def errors_table_html(errors)
		return "" if errors.empty? || errors.is_a?(String)
		# Si errors es un array de hashes, obtenemos las claves como encabezados
		# headers = errors.first.keys
		table = "<table border='0' style='border-collapse:collapse; margin-top:10px;'>"
		table += "<tbody>"
		errors.each do |err|
			table += "<tr>"
			table += "<td>#{err}</td>"
			table += "</tr>"
		end
		table += "</tbody></table>"
		table.html_safe
	end	
end
