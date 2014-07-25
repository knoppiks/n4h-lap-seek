require 'test_helper'
require 'integration/project_hierarchy/project_hierarchy_test_helper'
class SubscriptionWithHierarchyTest < ActionController::IntegrationTest
  include ProjectHierarchyTestHelper
  def setup
        sync_delayed_jobs
        login_as_test_user
        initialize_hierarchical_projects
  end


  test "rails 3 bug: before_add is not fired before the record is saved on `has_many :through` associations" do
      # no problem in the application, as work_groups are added directly with UI
      #problem in test is caused that the group_memberships instead of work_groups are assigned to person when created

      #BUG: `before_add` callbacks are fired before the record is saved on
      #`has_and_belongs_to_many` associations *and* on `has_many :through`
      #associations.  Before this change, `before_add` callbacks would be fired
      #before the record was saved on `has_and_belongs_to_many` associations, but
      #*not* on `has_many :through` associations.

      #this is solved in Rails 4 https://github.com/rails/rails/commit/b1656fa6305a5c8237027ab8165d7292751c0e86
      # add work groups via adding group_memberships which is the join table of people and work_groups
      #results: work_groups are added but before_add callbacks are not fired
      person = Factory(:person)

      #'before_add' callback of 'work_groups' association is not fired.
      #project subscriptions should be created before person is saved but not
      assert_equal true, person.project_subscriptions.empty?
  end

  test "add/remove_project_subscriptions_for_subscriber when adding/removing ancestors" do

    person = new_person_with_hierarchical_projects
    assert person.project_subscriptions.map(&:project).include?(@proj)

    new_parent_proj = Factory :project
    @proj_child1.parent = new_parent_proj
    @proj_child1.save
    @proj_child2.parent = new_parent_proj
    @proj_child2.save
    person.reload

    assert !person.project_subscriptions.map(&:project).include?(@proj)
    assert person.project_subscriptions.map(&:project).include?(new_parent_proj)

  end
    test "people subscribe to their projects and parent projects when their projects are assigned" do
      #when created without a project
      person = Factory(:brand_new_person)
      assert_equal 0, person.project_subscriptions.count

      #add 2 work_groups directly
      project1 = Factory :project, :parent => @proj
      project2 = Factory :project, :parent => @proj
      person.work_groups.create :project => project1, :institution => Factory(:institution)
      person.work_groups.create :project => project2, :institution => Factory(:institution)
      disable_authorization_checks do
        #save person in order to save built project subscriptions
        person.save!
      end
      assert_equal 3, person.project_subscriptions.count
    end


    test 'subscribing to a project subscribes existing and new items in the project AND NEW items in its ancestors' do
      # when person edits his profile to subscribe new project, only items in that direct project are subscribed
      child_project = Factory :project, :parent => @proj
      @proj.reload

      existing_subscribable = Factory :subscribable, :projects => [child_project]
      current_person.project_subscriptions.create(:project => child_project)
      new_subscribable = Factory :subscribable, :projects => [child_project]
      new_subscribable_proj =  Factory :subscribable, :projects => [@proj]

      assert existing_subscribable.subscribed?
      assert new_subscribable.subscribed?

      assert !@subscribables_in_proj.all?(&:subscribed?)
      assert new_subscribable_proj.subscribed?
    end


    test 'when the project tree updates, people subscribe to items in the new parent of the projects they are subscribed to' do
      child_project = Factory :project
      current_person.project_subscriptions.create :project => child_project
      child_project.reload
      assert !child_project.project_subscriptions.map(&:person).empty?
      disable_authorization_checks do
        child_project.parent = @proj
        child_project.save!
      end
      @subscribables_in_proj.each &:reload
      assert @subscribables_in_proj.all?(&:subscribed?)
    end


    test "subscribe/unsubscribe a project should subscribe/unsubscribe only itself rather that its parents" do
      add_project_subscriptions_attributes = {"2" => {"project_id" => @proj_child1.id.to_s, "_destroy" => "0", "frequency" => "daily"}, "22" => {"project_id" => @proj_child2.id.to_s, "_destroy" => "0", "frequency" => "weekly"}}
      person = User.current_user.person
      assert_equal 0, person.project_subscriptions.count

      put "/people/#{person.id}", id: person.id, person: {"project_subscriptions_attributes" => add_project_subscriptions_attributes}

      person.reload
      assert_equal 2, person.project_subscriptions.count

      remove_project_subscriptions_attributes = {"2" => {"id" => person.project_subscriptions.first.id, "project_id" => @proj_child1.id.to_s, "_destroy" => "1", "frequency" => "daily"}, "22" => {"id" => person.project_subscriptions.last.id, "project_id" => @proj_child2.id.to_s, "_destroy" => "1", "frequency" => "weekly"}}
      put "/people/#{person.id}", id: person.id, person: {"project_subscriptions_attributes" => remove_project_subscriptions_attributes}
      person.reload
      assert_equal 0, person.project_subscriptions.count
    end
    test "unassign a project will unsubscribe its parent projects unless the person also subscribes other sub-projects of the parent projects" do
      person = new_person_with_hierarchical_projects
      assert_equal 3, person.project_subscriptions.count

      # unassign one child project of @proj,
      #subscription of @proj is not deleted as there is still another child project subscribed
      person.work_groups.delete WorkGroup.where(:project_id => @proj_child1.id).first
      disable_authorization_checks do
        person.save
      end
      person.reload
      assert_equal 2, person.project_subscriptions.count

      #unassign all child projects
      person.work_groups.delete WorkGroup.where(:project_id => @proj_child2.id).first
      disable_authorization_checks do
        person.save
      end
      person.reload
      assert_equal 0, person.project_subscriptions.count

    end

    test "clear all subscriptions when no project is assigned to person" do
      person = new_person_with_hierarchical_projects
      #subscribe an individual item in another project
      person.subscriptions.build :subscribable => Factory(:subscribable)

      disable_authorization_checks do
        #save person in order to save built project subscriptions
        person.save!
      end

      #@proj,@proj_child1,@proj_child2 are subscribed
      assert_equal 3, person.project_subscriptions.count

      # 3 subscriptions from project subscription for @proj + 1 individual subscription
      assert_equal 4, person.subscriptions.count

      # unassign all related projects
      person.work_groups.delete_all
      disable_authorization_checks do
        person.save
      end
      person.reload
      assert_equal 0, person.project_subscriptions.count
      assert_equal 0, person.subscriptions.count

    end

end