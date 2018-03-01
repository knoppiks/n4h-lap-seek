require 'test_helper'
require 'integration/api_test_helper'

class DataFileCUDTest < ActionDispatch::IntegrationTest
  include ApiTestHelper

  def setup
    admin_login
    @clz = 'data_file'
    @plural_clz = @clz.pluralize
    @project = @current_user.person.projects.first
    investigation = Factory(:investigation, projects: [@project], contributor: @current_person)
    study = Factory(:study, investigation: investigation, contributor: @current_person)
    @assay = Factory(:assay, study: study, contributor: @current_person)
    @creator = Factory(:person)
    @publication = Factory(:publication, projects: [@project])
    @event = Factory(:event, projects: [@project], policy: Factory(:public_policy))

    template_file = File.join(ApiTestHelper.template_dir, 'post_max_data_file.json.erb')
    template = ERB.new(File.read(template_file))
    @to_post = JSON.parse(template.result(binding))
  end

  def populate_extra_attributes
    {}
  end

  def populate_extra_relationships
    extra_relationships = {}
    extra_relationships[:submitter] = { data: [{ id: @current_person.id.to_s, type: 'people' }] }
    extra_relationships[:people] = { data: [{ id: @current_person.id.to_s, type: 'people' },
                                            { id: @creator.id.to_s, type: 'people' }] }
    extra_relationships.with_indifferent_access
  end

  test 'can add content to API-created data file' do
    df = Factory(:api_pdf_data_file, contributor: @current_person)

    assert df.content_blob.no_content?
    assert df.can_download?(@current_user)
    assert df.can_edit?(@current_user)

    original_md5 = df.content_blob.md5sum
    put data_file_content_blob_path(df, df.content_blob), nil,
        'Accept' => 'application/json',
        'RAW_POST_DATA' => File.binread(File.join(Rails.root, 'test', 'fixtures', 'files', 'a_pdf_file.pdf'))

    assert_response :success
    blob = df.content_blob.reload
    refute_equal original_md5, blob.reload.md5sum
    refute blob.no_content?
    assert blob.file_size > 0
  end

  test 'cannot add content to API-created data file without permission' do
    df = Factory(:api_pdf_data_file, policy: Factory(:public_download_and_no_custom_sharing)) # Created by someone who is not currently logged in

    assert df.content_blob.no_content?
    assert df.can_download?(@current_user)
    refute df.can_edit?(@current_user)

    put data_file_content_blob_path(df, df.content_blob), nil,
        'Accept' => 'application/json',
        'RAW_POST_DATA' => File.binread(File.join(Rails.root, 'test', 'fixtures', 'files', 'a_pdf_file.pdf'))

    assert_response :forbidden
    blob = df.content_blob.reload
    assert_nil blob.md5sum
    assert blob.no_content?
  end

  test 'cannot add content to API-created data file that already has content' do
    df = Factory(:data_file, contributor: @current_person)

    refute df.content_blob.no_content?
    assert df.can_download?(@current_user)
    assert df.can_edit?(@current_user)

    original_md5 = df.content_blob.md5sum
    put data_file_content_blob_path(df, df.content_blob), nil,
        'Accept' => 'application/json',
        'RAW_POST_DATA' => File.binread(File.join(Rails.root, 'test', 'fixtures', 'files', 'another_pdf_file.pdf'))

    assert_response :bad_request
    blob = df.content_blob.reload
    assert_equal original_md5, blob.md5sum
    assert blob.file_size > 0
  end

  test 'can create data file with remote content' do
    stub_request(:get, 'http://mockedlocation.com/txt_test.txt').to_return(body: File.new("#{Rails.root}/test/fixtures/files/txt_test.txt"),
                                                                           status: 200, headers: { content_type: 'text/plain; charset=UTF-8' })
    stub_request(:head, 'http://mockedlocation.com/txt_test.txt').to_return(status: 200, headers: { content_type: 'text/plain; charset=UTF-8' })

    template_file = File.join(ApiTestHelper.template_dir, 'post_remote_data_file.json.erb')
    template = ERB.new(File.read(template_file))
    @to_post = JSON.parse(template.result(binding))

    assert_difference("#{@clz.classify}.count") do
      post "/#{@plural_clz}.json", @to_post
      assert_response :success
    end

    h = JSON.parse(response.body)

    hash_comparison(@to_post['data']['attributes'], h['data']['attributes'])
    hash_comparison(populate_extra_attributes, h['data']['attributes'])

    hash_comparison(@to_post['data']['relationships'], h['data']['relationships'])
    hash_comparison(populate_extra_relationships, h['data']['relationships'])
  end

  test 'can patch max data file' do
    df = Factory(:data_file, contributor: @current_person)
    id = df.id

    patch_file = File.join(Rails.root, 'test', 'fixtures', 'files', 'json', 'templates', "patch_max_data_file.json.erb")
    the_patch = ERB.new(File.read(patch_file))
    @to_patch = JSON.parse(the_patch.result(binding))

    assert_no_difference( "#{@clz.classify}.count") do
      patch "/#{@plural_clz}/#{df.id}.json", @to_patch
      assert_response :success
    end

    h = JSON.parse(response.body)
    # Check the changed attributes and relationships
    hash_comparison(@to_patch['data'], h['data'])
  end
end
