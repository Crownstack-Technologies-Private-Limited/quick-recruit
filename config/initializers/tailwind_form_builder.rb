class TailwindFormBuilder < ActionView::Helpers::FormBuilder
  %w[rich_text_area].each do |method_name|
    define_method(method_name) do |name, title, *args|
      @template.content_tag :div do
        label(name, label_text(title, args.extract_options!), class: "block mb-2 text-sm font-medium text-gray-900 dark:text-white") +
        (@template.content_tag :div, class: "mt-1" do
          super(name, options.reverse_merge(class: "form-text-field"))
        end)
      end
    end
  end

  def text_field(method, title, opts = {})
    default_opts = { class: "form-text-field #{"border-red-400" if @object.errors.any?}" }
    merged_opts = default_opts.merge(opts)
    @template.content_tag :div do
      label(method, label_text(title, opts), class: "block mb-2 text-sm font-medium text-gray-900 dark:text-white") +
      (@template.content_tag :div, class: "mt-1" do
        super(method, merged_opts)
      end)
    end
  end

  def rich_text_area(method, opts = {})
    default_opts = { class: "form-text-field #{"border-red-400" if @object.errors.any?}" }
    merged_opts = default_opts.merge(opts)
    @template.content_tag :div do
      (@template.content_tag :div, class: "mt-1" do
        super(method, merged_opts)
      end)
    end
  end

  def text_area(method, title, opts = {})
    default_opts = { class: "form-text-field" }
    merged_opts = default_opts.merge(opts)
    @template.content_tag :div do
      label(method, label_text(title, opts), class: "block mb-2 text-sm font-medium text-gray-900 dark:text-white") +
      (@template.content_tag :div, class: "mt-1" do
        super(method, merged_opts)
      end)
    end
  end

  def password_field(method, title, opts = {})
    default_opts = { class: "form-text-field #{"border-red-400" if @object.errors.any?}" }
    merged_opts = default_opts.merge(opts)
    @template.content_tag :div do
      label(method, label_text(title, opts), class: "block mb-2 text-sm font-medium text-gray-900 dark:text-white") +
      (@template.content_tag :div, class: "mt-1" do
        super(method, merged_opts)
      end)
    end
  end

  private

  def label_text(title, opts)
    return title unless opts[:required]

    "#{title} <span class='text-red-600'>*</span>".html_safe
  end
end

