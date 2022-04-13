module FairSignposting
  extend ActiveSupport::Concern

  def fair_signposting
    parent_asset = resource_for_controller
    display_asset = versioned_resource_for_controller || parent_asset
    return unless display_asset&.is_a?(ApplicationRecord)
    url_opts = display_asset.respond_to?(:version) ? { version: display_asset.version } : {}
    self_url = polymorphic_url(parent_asset, **url_opts)
    links = []

    # describedby
    links << [self_url, { rel: :describedby, type: :datacite_xml }] if display_asset&.respond_to?(:datacite_metadata)
    links << [self_url, { rel: :describedby, type: :jsonld }] if display_asset&.schema_org_supported?
    links << [self_url, { rel: :describedby, type: :rdf }] if Seek::Util.rdf_capable_types.include?(controller_model)

    # cite-as
    links << [display_asset.doi_identifier, { rel: :'cite-as' }] if display_asset.respond_to?(:doi) && display_asset.doi.present?

    # item
    if display_asset.respond_to?(:ro_crate)
      links << [polymorphic_url([:ro_crate, parent_asset], **url_opts), { rel: :item, type: :zip }]
    elsif display_asset.respond_to?(:content_blobs) && display_asset.content_blobs.any?
      links << [polymorphic_url([:download, parent_asset], **url_opts), { rel: :item, type: :zip }]
    elsif display_asset.respond_to?(:content_blob) && display_asset.content_blob
      links << [polymorphic_url([:download, parent_asset], **url_opts), { rel: :item, type: display_asset.content_blob.content_type }]
    end

    if links.any?
      h = links.map do |url, props|
        s = "<#{url}>"
        props.each do |k, v|
          v = Mime::Type.lookup_by_extension(v).to_str if k == :type && v.is_a?(Symbol)
          s << " ; #{k}=\"#{v}\""
        end
        s
      end.join(', ')
      response.set_header('Link', h)
    end
  end
end
