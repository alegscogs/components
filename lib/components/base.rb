module Components
  class Base
    include Rails.application.routes.url_helpers
    include ::ActiveSupport::Configurable
    include ::ActionController::Helpers
    include ::Components::Caching

    # for request forgery protection compatibility
    attr_accessor :form_authenticity_token #:nodoc:
    delegate :request_forgery_protection_token, :allow_forgery_protection, :to => "ActionController::Base"
    def protect_against_forgery? #:nodoc:
      allow_forgery_protection && request_forgery_protection_token
    end

    class << self
      def view_paths
        @view_paths ||= ::ActionView::Base.process_view_paths([Rails.root.join('app', 'components')])
      end

      def path #:nodoc:
        @path ||= self.to_s.sub("Component", "").underscore
      end
      alias_method :controller_path, :path
    end

    # must be public for access from ActionView
    def logger #:nodoc:
      Rails.logger
    end

    protected

    # See Components::ActionController#standard_component_options
    def standard_component_options; end

    # When the string your component must return is complex enough to warrant a template file,
    # this will render that file and return the result. Any template engine (erb, haml, etc.)
    # that ActionView is capable of using can be used for templating.
    #
    # All instance variables that you create in the component action will be available from
    # the view. There is currently no other way to provide variables to the views.
    #
    # === Inferred Template Name
    #
    # If you call render without a file name, it will:
    #  * assume that the name of the calling method is also the name of the template file
    #  * search for the named template file in the directory of this component's views, then the directories of all parent components
    #
    # This means that if you have:
    #
    #   class UsersComponent < Components::Base
    #     def details(user_id)
    #       render
    #     end
    #   end
    #
    # Then render will essentially assume that you meant to render "users/details", which may
    # be found at "app/components/users/details.erb".
    def render(file = nil)
      # infer the render file basename from the caller method.
      unless file
        caller.first =~ /`([^']*)'/
        file = $1.sub("_without_caching", '')
      end

      # pick the closest parent component with the file
      component = self.class
      details = {:locale => [], :formats => [], :handlers => ::ActionView::Template::Handlers.extensions}
      unless file.include?("/")
        until component.view_paths.exists?(file, component.path, false, details) or component.superclass == Components::Base
          component = component.superclass
        end
      end

      # render the file
      view_context.render(:file => "#{component.path}/#{file}")
    end

    def view_context #:nodoc:
      self.class.view_context_class.new(self.class.view_paths, assigns_for_view, self)
    end

    class << self
      def view_context_class
        @view_context_class ||= begin
          controller = self
          Class.new(Components::View) do
            include controller._routes.url_helpers
            include controller._helpers
          end
        end
      end
    end

    # should return a hash of all instance variables to assign to the view
    def assigns_for_view #:nodoc:
      @assigns_for_view ||= (instance_variables - unassignable_instance_variables).inject({}) do |hash, var|
        hash[var[1..-1]] = instance_variable_get(var)
        hash
      end
    end

    # should name all of the instance variables used by Components::Base that should _not_ be accessible from the view.
    def unassignable_instance_variables #:nodoc:
      %w(@template @assigns_for_view)
    end
  end
end
