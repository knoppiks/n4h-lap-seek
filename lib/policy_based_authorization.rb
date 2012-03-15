require 'project_compat'
module Acts
  module Authorized
    module PolicyBasedAuthorization
      def self.included klass
        klass.extend ClassMethods
        klass.class_eval do
          belongs_to :contributor, :polymorphic => true unless method_defined? :contributor
          after_initialize :contributor_or_default_if_new

          #checks a policy exists, and if missing resorts to using a private policy
          after_initialize :policy_or_default_if_new

          include ProjectCompat unless method_defined? :projects

          belongs_to :policy, :required_access_to_owner => :manage, :autosave => true
        end
      end

      module ClassMethods
      end

      def contributor_credited?
        true
      end

      def private?
        policy.private?
      end

      def public?
        policy.public?
      end

      def default_policy
        Policy.default
      end

      def policy_or_default
        if self.policy.nil?
          self.policy = default_policy
        end
      end

      def policy_or_default_if_new
        if self.new_record?
          policy_or_default
        end
      end

      def default_contributor
        User.current_user
      end

      #when having a sharing_scope policy of Policy::ALL_SYSMO_USERS it is concidered to have advanced permissions if any of the permissions do not relate to the projects associated with the resource (ISA or Asset))
      #this is a temporary work-around for the loss of the custom_permissions flag when defining a pre-canned permission of shared with sysmo, but editable/downloadable within mhy project
      #other policy sharing scopes are simpler, and are concidered to have advanced permissions if there are more than zero permissions defined
      def has_advanced_permissions?
        if policy.sharing_scope==Policy::ALL_SYSMO_USERS
          !(policy.permissions.collect{|p| p.contributor} - projects).empty?
        else
          policy.permissions.count > 0
        end
      end

      def contributor_or_default_if_new
        if self.new_record? && contributor.nil?
          self.contributor = default_contributor
        end
      end
      #contritutor or person who can manage the item and the item was published
      def can_publish?
        ((Ability.new(User.current_user).can? :publish, self) && self.can_manage?) || self.contributor == User.current_user || try_block{self.contributor.user} == User.current_user || (self.can_manage? && self.policy.sharing_scope == Policy::EVERYONE) || Seek::Config.is_virtualliver
      end

      #use request_permission_summary to retrieve who can manage the item
      def people_can_manage
        contributor = self.contributor.kind_of?(Person) ? self.contributor : self.contributor.try(:person)
        return [[contributor.id, "#{contributor.first_name} #{contributor.last_name}", Policy::MANAGING]] if policy.blank?
        creators = is_downloadable? ? self.creators : []
        asset_managers = projects.collect(&:asset_managers).flatten
        grouped_people_by_access_type = policy.summarize_permissions creators,asset_managers, contributor
        grouped_people_by_access_type[Policy::MANAGING]
      end

      AUTHORIZATION_ACTIONS.each do |action|
        eval <<-END_EVAL
          def can_#{action}? user = User.current_user
              if Seek::Config.auth_caching_enabled
                key = cache_keys(user, "#{action}")
                new_record? || Rails.cache.fetch(key) {perform_auth(user,"#{action}") ? :true : :false} == :true
              else
                new_record?  || perform_auth(user,"#{action}")
              end
          end
        END_EVAL
      end

      def perform_auth user,action
        (Authorization.is_authorized? action, nil, self, user) || (Ability.new(user).can? action.to_sym, self) || (Ability.new(user).can? "#{action}_asset".to_sym, self)
      end

      #returns a list of the people that can manage this file
      #which will be the contributor, and those that have manage permissions
      def managers
        #FIXME: how to handle projects as contributors - return all people or just specific people (pals or other role)?
        people=[]
        unless self.contributor.nil?
          people << self.contributor.person if self.contributor.kind_of?(User)
          people << self.contributor if self.contributor.kind_of?(Person)
        end

        self.policy.permissions.each do |perm|
          unless perm.contributor.nil? || perm.access_type!=Policy::MANAGING
            people << (perm.contributor) if perm.contributor.kind_of?(Person)
            people << (perm.contributor.person) if perm.contributor.kind_of?(User)
          end
        end
        people.uniq
      end

      def cache_keys user, action

        #start off with the keys for the person
        keys = generate_person_key(user.try(:person))

        #action
        keys << "can_#{action}?"

        #item (to invalidate when contributor is changed)
        keys << self.cache_key

        #item creators (to invalidate when creators are changed)
        if self.respond_to? :assets_creators
          keys |= self.assets_creators.sort_by(&:id).collect(&:cache_key)
        end

        #policy
        keys << policy.cache_key

        #permissions
        keys |= policy.permissions.sort_by(&:id).collect(&:cache_key)

        keys
      end

      def generate_person_key person
        keys = [person.try(:cache_key)]
        #group_memberships + favourite_group_memberships
        unless person.nil?
           keys |= person.group_memberships.sort_by(&:id).collect(&:cache_key)
           keys |= person.favourite_group_memberships.sort_by(&:id).collect(&:cache_key)
        end
        keys        
      end
    end
  end
end
