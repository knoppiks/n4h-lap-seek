module ResourceListHelper
  include ResourceListItemHelper

  def resource_list_table_row(resource, tableview_columns)
    content_tag :tr, class: :list_item do
      tableview_columns.collect do |column|
        content_tag :td do
          resource_list_table_column(resource, column)
        end
      end.join.html_safe
    end
  end

  def resource_list_table_column(resource, column)
    raise 'Invalid column' unless resource.allowed_table_columns.include?(column)

    column_value = resource.send(column)
    case column
    when 'title'
      list_item_title resource, {}
    when 'projects'
      column_value.uniq.map { |p| link_to p.title, p }.join(', ').html_safe
    when 'contributor'
      link_to column_value.name, column_value
    when 'tags'
      column_value.join(',')
    when 'creators'
      table_item_person_list column_value
    when 'assay_type_uri'
      link_to_assay_type(resource)
    when 'technology_type_uri'
      link_to_technology_type(resource)
    else
      text_or_not_specified(column_value, length: 300, auto_link: true, none_text: '')
    end
  end

  def table_item_person_list(contributors, other_contributors = nil, key = t('creator').capitalize)
    contributor_count = contributors.count
    contributor_count += 1 unless other_contributors.blank?
    html = ''
    other_html = ''
    html << if key == 'Author'
              contributors.map do |author|
                if author.person
                  link_to author.full_name, show_resource_path(author.person)
                else
                  author.full_name
                end
              end.join(', ')
            else
              contributors.map do |c|
                link_to truncate(c.title, length: 75), show_resource_path(c), title: get_object_title(c)
              end.join(', ')
            end
    unless other_contributors.blank?
      other_html << ', ' unless contributors.empty?
      other_html << other_contributors
    end
    other_html << 'None' if contributor_count.zero?
    html.html_safe + other_html
  end
end
