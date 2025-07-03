require 'caxlsx'

class ImportXslxErrorExporter
  # rows_with_errors: Array de arrays, cada uno representa una fila original (dup)
  # errors: Array de strings, cada uno es el mensaje de error correspondiente a la fila
  # headers: Array de strings, los encabezados de las columnas (opcional)
  # file_path: String, ruta donde guardar el archivo temporalmente
  def self.export(rows_with_errors, file_path)
    Axlsx::Package.new do |p|
      p.workbook.add_worksheet(name: "Errores de importación") do |sheet|
        # Agregar encabezados si se proporcionan
        sheet.add_row ['Fila', 'Descripción del error']

        rows_with_errors.each do |row|
          
          # Duplicar la fila y agregar el error en la última celda
          sheet.add_row row.split(':')
        end
      end
      p.serialize(file_path)
    end
    file_path
  end
end