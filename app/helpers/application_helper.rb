module ApplicationHelper
	def render_haml(haml, locals = {})
		Haml::Engine.new(haml.strip_heredoc, format: :html5).render(locals)
	end

	def to_bs value
		ActionController::Base.helpers.number_to_currency(value, unit: 'Bs.', separator: ",", delimiter: ".")
	end

	def badge_toggle_section_qualified section

		if section.qualified?
			title = 'Habilitar al profesor para calificar de nuevo (Abrir)'
			value = false
			icon = 'fas fa-rotate-right'
			type = 'bg-warning'
		else
			title = 'Marcar como calificada por el profesor (Cerrar)'
			value = true
			icon = 'fas fa-check'
			type = 'bg-success'
		end

		url = "/sections/#{section.id}/change_qualification_status?section[qualified]=#{value}"
		badge_toggle type, icon, url, title, ''
	end

	def badge_toggle type, icon, href, title_tooltip, value, onclick_action=nil

		target = ''
		rel = ''

		if (icon.include? 'fa-download')
			target = '_blank'
			rel = 'noopener noreferrer'
		end
		link_to href, class: "badge #{type}", 'data-bs-toggle': :tooltip,  title: title_tooltip, onclick: onclick_action, target: target, rel: rel do
			capture_haml{"<i class= '#{icon}'></i> #{value}".html_safe}
		end
	end

	def btn_toggle type, icon, href, title_tooltip, value, onclick_action=nil

		target = ''
		rel = ''

		if (icon.include? 'fa-download')
			target = '_blank'
			rel = 'noopener noreferrer'
		end
		link_to href, class: "btn btn-sm #{type}", 'data-bs-toggle': :tooltip, title: title_tooltip, onclick: onclick_action, target: target, rel: rel do
			capture_haml{"<i class= '#{icon}'></i> #{value}".html_safe}
		end
	end

	def btn_toggle_download classes, href, title_tooltip, value, onclick_action=nil
		btn_toggle classes, 'fa fa-download', href, title_tooltip, value, onclick_action
	end
	
	def button_add_section course_id
		content_tag :button, 'data-bs-target': "#NewSectionModal", class: "btn btn-sm btn-success mx-1 addSection", "data-bs-toggle": :modal, course_id: course_id, onclick: "$('#section_course_id').val(this.attributes['course_id'].value);" do		
			capture_haml{"<i class='fas fa-plus'></i>".html_safe }
		end
		
	end

	def total_sections_stiky total
		sticky_label 0, 0, 'bg-success', 'text-dark', 'Total Secciones', total
	end

	def sticky_label top, right, bg_color, text_color, title, content
		content_tag :div, 'data-bs-toggle': :tooltip, title: title, class: "btn btn-sm #{bg_color} #{ text_color}", style: "top: #{top}px; right: #{right};font-size: xx-small;" do
			capture_haml{"#{content}".html_safe }
		end	
	end

	
	def link_academic_records_csv object 
		id = object.id
		total = object.academic_records.count
		cod = object.name
		cod ||= object.code
		cod ||= object.id
		model_name = object.class.name
		label_link_with_tooptip("/export_csv/academic_records/#{id}?model_name=#{model_name}", 'bg-success', "<i class='fa-solid fa-user-graduate'></i><i class='fa-solid fa-down-long'></i>", "Descargar #{total} Regisrtos Académicos del #{(translate_model model_name.underscore, 'one').titleize} #{cod}", placement='left') if total > 0
	end

	def link_enroll_academic_process_csv object 
		id = object.id
		total = object.enroll_academic_processes.count
		cod = object.name
		cod ||= object.code
		cod ||= object.id
		model_name = object.class.name
		label_link_with_tooptip("/export_csv/enroll_academic_processes/#{id}?model_name=#{model_name}", 'bg-success', "<i class='fa-solid fa-user-graduate'></i><i class='fa-solid fa-down-long'></i>", "Descargar #{total} Inscritos del #{(translate_model model_name.underscore, 'one').titleize} #{cod}", placement='left') if total > 0
	end	
	
	def label_link_with_tooptip(href, klazz, content, title, placement='top')

		content_tag :a, href: href, rel: :tooltip, 'data-bs-toggle': :tooltip, 'data-bs-placement': placement, 'data-bs-original-title': title do
			capture_haml{"<span class='text-center badge #{klazz}'>#{content}</span>".html_safe }
		end	
	end	

	
	# General Tooltip
	def general_tooltip(content, title, placement='top')
		content_tag :b, rel: :tooltip, 'data-bs-toggle': 'tooltip', 'data-bs-placement': placement, 'data-bs-original-title': title do
			capture_haml{content}
		end	
	end

	# General link
	def general_link(href, content)
		content_tag :a, href: href do
			content
		end
	end

	# General Label
	def label_status(klazz, content, type='badge')
		if content.blank?
			content = 'Sin Información'
			klazz = 'bg-secondary' 
		end
		klazz += ' text-dark' if (klazz.include? 'bg-info')
		capture_haml{"<span class='text-center #{type} #{klazz}'>#{content}</span>".html_safe }
	end

	def link_with_tooltip(href, klazz, content, title, placement='top', label=nil)
		 
		aux = general_link(href, label_status(klazz, content, label) )
		general_tooltip(aux, title, placement)		
	end

	def label_status_with_tooltip(klazz, content, title, placement='top')
		general_tooltip(label_status(klazz, content), title, placement)
	end

	def label_link_with_tooltip(href, klazz, content, title, placement='top')
		if href.blank?
			label_status_with_tooltip(klazz, content, title, placement)
		else
			link_with_tooltip(href, klazz, content, title, placement, 'badge')
		end
	end	

	def btn_link_with_tooptip(href, klazz, content, title, placement='top')
		link_with_tooltip(href, klazz, content, title, placement, 'btn btn-sm')
	end	
	

	def translate_model model, singular='other'
		I18n.t("activerecord.models.#{model}.#{singular}")
	end

	def checkbox_auth id, action, value, area_id, onclick=nil

		content_tag :a do
			check_box_tag "[model#{id}][can_#{action}]", nil, value, {class: "area#{area_id} can_all#{id} read#{id}", onclick: onclick}
		end
	end

	def simple_toggle href, value, title_tooltip, color_type, icon, onclick_action = nil
		target = (href.include? 'descargar') ? '_blank' : ''
		link_to href, class: "tooltip-btn text-#{color_type} btn btn-sm", onclick: onclick_action, target: target, 'data-bs-toggle': :tooltip, title: title_tooltip do
			capture_haml{"<i class= '#{icon}'></i> #{value}".html_safe}
		end

	end

	def signatures

		capture_haml {
			".signatures
				.font-title.text-center FACULTAD
					%table.no_border
						%thead
							%tr
							%th.text-center{style: 'width: 500px'} JURADO EXAMINADOR
							%th.text-center{style: 'width: 500px'} SECRETARÍA
					%br
					%table.no_border
						%thead
							%tr
								%th APELLIDOS Y NOMBRES
								%th FIRMAS
								%th 
							%tr{style: 'height:30px'}
								%th _________________________________
								%th ______________________
								%th NOMBRE ______________________        
							%tr{style: 'height:30px'}
								%th _________________________________
								%th ______________________
								%th FIRMA _______________________
							%tr{style: 'height:30px'}
								%th _________________________________
								%th ______________________
								%th FECHA _______________________"
		}

	end	

end
