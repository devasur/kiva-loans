    ###
    @collection.on 'resorted', (m)=>
      # remove this table row from the list view 
      # and reinsert it at it's new sorted index
      # according to the collection
      # this type of sort is more efficient 
      # than re-rendering the entire list view
      
      if m.pledge is 0 and not m.lastChangeIsPositive
        m.view.$el.remove()
      modelIds = _.pluck @collection.models, 'id'
      newIndex = _.indexOf modelIds, m.get('id')
      m.view.$el.slideUp 1000, =>
        m.view.$el.remove()
        m.view.$el.insertBefore($(@$('tbody.my-loans tr')[newIndex])).slideDown(500)
        m.view.delegateEvents()
      @delegateEvents()
    ###