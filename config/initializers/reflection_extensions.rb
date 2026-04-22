ActiveRecord::Associations::Builder::HasMany.singleton_class.prepend(
  Module.new do
    def valid_options(options)
      super + [ :merge_policy, :natural_key ]
    end
  end
)

ActiveRecord::Associations::Builder::HasOne.singleton_class.prepend(
  Module.new do
    def valid_options(options)
      super + [ :merge_policy, :natural_key ]
    end
  end
)
