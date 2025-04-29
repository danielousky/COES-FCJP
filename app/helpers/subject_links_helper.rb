module SubjectLinksHelper
	def render_haml(haml, locals = {})
		Haml::Engine.new(haml.strip_heredoc).render(locals)
	end

	def badge_tipo_subject(asignatura)
		capture_haml do
			"<span class='badge bg-info tooltip-btn text-dark'>#{asignatura.subject_type&.name&.titleize}</span>".html_safe
		end
	end

	def badge_level_subject(asignatura)
		capture_haml do
			"<span class='badge bg-info tooltip-btn text-dark' data-bs-toggle='tooltip' title= 'Año/Semestre'>#{asignatura.ordinal}</span>".html_safe
		end
	end


	def badge_order_subject(asignatura)

		capture_haml do
			if asignatura.ordinal.eql? 0
				aux = asignatura.subject_type ? asignatura.subject_type&.name&.titleize : 0
			else
				aux = asignatura.ordinal
			end
			"<span class='badge bg-info tooltip-btn' data-toggle='tooltip' title= 'Orden'>#{aux}</span>".html_safe
		end
	end

	def subject_full_description_badges(asignatura)
		capture_haml do
			nivel = badge_tipo_subject(asignatura)
			tipo = badge_level_subject(asignatura)
			detalle_asig = simple_toggle "/admin/subject/#{asignatura.id}", "", "Ir al detalle de " + asignatura.desc, 'primary', "fa fa-search"
			"#{nivel} #{tipo} #{detalle_asig} | #{asignatura.desc}".html_safe
		end
	end

	def description_subject_tree(dep, adelante, admin)

		capture_haml do
			delete_btn = btn_delete_depend(dep).html_safe if (admin&.authorized_delete? 'Subject')
			asig = adelante ? dep.depend_subject : dep.prelate_subject
			detalle_asig = subject_full_description_badges(asig)			
			# detalle_asig = simple_toggle "/admin/subject/#{asig.id}", "", "Ir al detalle de " + asig.desc, 'primary', "fa fa-search"
			"#{delete_btn} #{detalle_asig}".html_safe
		end
	end

	def btn_delete_depend(dep)
		link_to "/subject_links/#{dep.id}.json", class: "tooltip-btn text-danger", 'data-bs-toggle': :tooltip, title: 'Eliminar prelación', method: :delete, onclick: "$('#dep#{dep.id}').remove();" do
			capture_haml{"<i class='fa fa-trash'></i>".html_safe}
		end
	end

end
