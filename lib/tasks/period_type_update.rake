namespace :update do
  desc "Actualiza los nombres de Periods y AcademicProcesses tras el cambio de PeriodType.code"
  task period_names: :environment do
    puts "Iniciando actualización de Periods y AcademicProcesses..."
    # Actualizar PeriodTypes
    PeriodType.find(1).update(code: '01')
    PeriodType.find(2).update(code: '02')
    puts "PeriodTypes actualizados."
    
    # Actualizar Periods
    Period.joins(:period_type).find_each do |period|
      if period.period_type.code == '01'
        period.update(name: period.name.gsub(/\bI\b/, '01'))
      elsif period.period_type.code == '02'
        period.update(name: period.name.gsub(/\bII\b/, '02'))
      end
    end

    # Actualizar AcademicProcesses
    AcademicProcess.joins(:period_type).find_each do |ap|
      if ap.period_type.code == '01'
        ap.update(name: ap.name.gsub(/\bI\b/, '01'))
      elsif ap.period_type.code == '02'
        ap.update(name: ap.name.gsub(/\bII\b/, '02'))
      end
    end

    puts "Actualización completada."
  end
end