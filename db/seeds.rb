p '      Creada Facultad!    '.center(200, '=') if Faculty.create!(code: 'FCJP', coes_boss_name: 'Pedro Coronado', contact_email: 'soporte@coesfcjp.com', name: 'Facultad de Ciencias Jurídicas y Políticas', short_name: 'FCJP')

p '      Creadas Escuelas!    '.center(200, '=') if Faculty.first.schools.create!([
    {type_entity: :pregrado, short_name: "DERECHO", name: "ESCUELA DE DERECHO",	code: 'DER'},
    {type_entity: :pregrado, short_name: "POLITICOS", name: "ESCUELA DE ESTUDIOS POLÍTICOS Y ADMINISTRATIVOS", code: 'POL'},
])

p '      Creados Primeros Tipos de Períodos!    '.center(200, '=') if PeriodType.create([{code: 'I', name: 'Primero'}, {code: 'II', name: 'Segundo'}, {code: 'U', name: 'Único'}, {code: 'I', name: 'Intensivo'}])

p '      Creado Primer Usuario!    '.center(200, '=') if user = User.create!(email: 'moros.daniel@gmail.com', first_name: 'Daniel Josué', last_name: 'Moros Castillo', ci: '15573230', password: 123123)

p '      Creado Primer Admin!    '.center(200, '=') if Admin.create!(user_id: user.id, role: :desarrollador)

p '      Creado Segundo Usuario!    '.center(200, '=') if user = User.create!(email: 'danielito.moros03@gmail.com', first_name: 'Daniel Alexander', last_name: 'Moros Contreras', ci: '30035269', password: 123123)

p '      Creado Segundo Admin!    '.center(200, '=') if Admin.create!(user_id: user.id, role: :desarrollador)


p '      Creados Primeros Bancos!    '.center(200, '=') if Bank.create([{code: "0006", name: "Banco de Coro"},
{code: "0007", name: "Banfoandes"},
{code: "0008", name: "Banco Guayana"},
{code: "0102", name: "Banco de Venezuela"},
{code: "0104", name: "Banco Venezolano de Crédito"},
{code: "0105", name: "Banco Mercantil"},
{code: "0108", name: "Banco Provincial"},
{code: "0114", name: "Bancaribe"},
{code: "0115", name: "Banco Exterior"},
{code: "0116", name: "Banco Occidental de Descuento"},
{code: "0121", name: "Corp Banca"},
{code: "0128", name: "Banco Caroní"},
{code: "0133", name: "Banco Federal"},
{code: "0134", name: "Banesco"},
{code: "0137", name: "Banco Sofitasa"},
{code: "0138", name: "Banco Plaza"},
{code: "0140", name: "Banco Canarias de Venezuela"},
{code: "0141", name: "Banco Confederado"},
{code: "0145", name: "Banco de Comercio Exterior"},
{code: "0146", name: "Banco de la Gente Emprendedora"},
{code: "0148", name: "Total Bank"},
{code: "0151", name: "Banco Fondo Común"},
{code: "0156", name: "100% Banco"},
{code: "0157", name: "Banco Del Sur"},
{code: "0158", name: "Central Banco Universal"},
{code: "0161", name: "Banpro"},
{code: "0163", name: "Banco Del Tesoro"},
{code: "0166", name: "Banco Agrícola de Venezuela"},
{code: "0168", name: "Bancrecer"},
{code: "0169", name: "Mi Banco"},
{code: "0171", name: "Banco Activo"},
{code: "0172", name: "Bancamiga"},
{code: "0173", name: "Banco Internacional de Desarrollo"},
{code: "0174", name: "Banplus"},
{code: "0175", name: "Banco Bicentenario"},
{code: "0176", name: "Novo Banco"},
{code: "0177", name: "Banco de la Fuerza Armada Nacional Bolivariana"},
{code: "0190", name: "Citibank"},
{code: "0191", name: "Banco Nacional de Crédito"},
{code: "0601", name: "Instituto Municipal de Crédito Popular"}])

# Agregar Código a Tipos de Admisión

p '      Creados Primeros Tipos de Admisión!    '.center(200, '=') if AdmissionType.create(
    [{code: "0600", name: "SIMULTANEOS"},
 {code: "0131", name: "ACTA CONVENIO (DOCENTE)"},
 {code: "0140", name: "ACTA CONVENIO (ADMIN)"},
 {code: "0133", name: "ACTA CONVENIO (OBRERO)"},
 {code: "0132", name: "ACTA CONVENIO (EMPLEADOS)"},
 {code: "0102", name: "SIMADI"},
 {code: "0111", name: "DIPLOMATICO"},
 {code: "0105", name: "AMAZONAS"},
 {code: "0137", name: "ART. 25 (DEPORTE)"},
 {code: "0138", name: "ART. 25 (ARTISTAS)"},
 {code: "0107", name: "DISCAPACIDAD"},
 {code: "1400", name: "EGRESADOS (UCV)"},
 {code: "1500", name: "EGRESADOS (INST. VENEZOLANAS)"},
 {code: "0410", name: "ART. 6"},
 {code: "0417", name: "CAMBIO: 158"},
 {code: "0141", name: "ART. 10"},
 {code: "0110", name: "ART. 25 (CULTURA)"},
 {code: "0114", name: "CURSO INTRODUCTORIO"},
 {code: "0300", name: "EQUIVALENCIA"},
 {code: "0129", name: "SAMUEL ROBINSON"},
 {code: "1300", name: "EQUIVALENCIA (INST. EXTRANJERAS)"},
 {code: "1200", name: "EQUIVALENCIA (INST. VENEZOLANAS)"},
 {code: "1100", name: "EQUIVALENCIA EN LA UCV"},
 {code: "0118", name: "EUS"},
 {code: "0108", name: "MPPS"},
 {code: "0800", name: "REVALIDA"},
 {code: "0143", name: "TRASLADO DE UNA ESCUELA A OTRA"},
 {code: "0144", name: "PARLAMENTO INDIGENA"},
 {code: "1000", name: "PROCECUCION DE ESTUDIOS EUS"},
 {code: "0101", name: "OPSU"},
 {code: "0121", name: "OPSU/COLA"},
 {code: "0119", name: "RECLAMO OPSU"}]
)

p '      Creadas Primeras Config Generales!    '.center(200, '=') if GeneralSetup.create!([
    {clave: 'ENABLED_POST_QUALIFICACION', description: 'Desactivar calificaciones posteriores', valor: 'NO'},
    {clave: 'SEND_WELLCOME_MAILER_ON_CREATE_USER', description: 'Enviar correo de bienvenida al crear usuario', valor: 'NO'}
])

p '      Creados Tipos de Asignatura!    '.center(200, '=') if  SubjectType.create!([{code: 'OB', name: 'OBLIGATORIA'}, {code: 'L', name: 'ELECTIVA'}, {code: 'OP', name: 'OPTATIVA'}, {code: 'P', name: 'PROYECTO'}])

p '      Creados Primeros Tipos de Asignaturas!    '.center(200, '=') if SubjectType.create([{code: :OP, name: :optativa}, {code: :L, name: :electiva}, {code: :OB, name: :obligatoria}, {code: :P, name: :proyecto}])

p '      Creados Primeros Grupos de Tutoriales!    '.center(200, '=')  if GroupTutorial.create([{name_group: 'Secciones'},
{name_group: 'Profesores'},
{name_group: 'Estudiantes'},
{name_group: 'Periodos', description: 'Entidad Periodos'},
{name_group: 'Asignaturas', description: 'Entidad Periodos'},
{name_group: 'Planes de Estudio', description: 'Acceso a las Funciones de la Entidad Planes de Estudio'},
{name_group: 'Escuela', description: 'Acceso a las Funciones de la Entidad Escuela'},
{name_group: 'Configuración General', description: 'Ingreso al Sistema'}])

p '      FINAL    '.center(400, '*')


