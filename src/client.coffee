# alias for the global window context
w = window

# all views share this generic open method
Backbone.View::open = (parentEl = '.main')->
  @$el.appendTo parentEl
  @

# make setTimeout and setInterval less awkward
# by switching the parameters!!
w.wait = (someTime,thenDo) ->
  setTimeout thenDo, someTime

w.doEvery = (someTime,action)->
  setInterval action, someTime

# MODELS
class Loan extends Backbone.Model
  initialize: ->
    @on 'change:pledge', =>
      @collection.trigger 'update:pledgeTotal', (@collection.pledgeTotal())

  profileImage: ->
    "http://www.kiva.org/img/s100/#{@get('image').id}.jpg"
  
  flagImage: ->
    "/flag/#{@get('location').country_code}"

  percFunded: (withHelp = 0)->
    Math.floor (@get('funded_amount')+withHelp)*100/@get('loan_amount')

  # get the integer value for the current pledge
  getPledge: ->
    parseInt @get('pledge'), 10

  # make sure the pledge is either nothing or an integer
  validate: (attrs)->
    # console.log 'lstchg: ',@lastChangeIsPositive = parseInt(attrs.pledge,10) > @getPledge()
    ok = /(''|^[0-9]+$)/.test(attrs.pledge)
    return 'not a number' unless ok

  # test if loan matches a search term
  matches: (term)->
    re = RegExp term, 'gi'
    fieldsToSearch = (@get('name')+@get('activity')+@get('use')+@get('country'))
    re.test fieldsToSearch


class Loans extends Backbone.Collection
  model: Loan
  url: 'http://api.kivaws.org/v1/loans/newest.json'

  initialize: ->
    # keep track of the lastest loaded loan post_date
    @latestLoad = moment().valueOf()
    # ...and the last page loaded
    @page = 1

    # fetch newest loans every 10 seconds
    checkForNewLoans = doEvery 10000, => @fetch({add:true})

  # keep these sorted by the posted_date
  comparator: (loan)->
    console.log 'sorting'
    1/parseInt(loan.get('postedMoment'),10)

  # total of current pledges
  pledgeTotal: ->
    _.reduce @models, (runningTotal, loan)-> 
      runningTotal + loan.getPledge()
    ,0

  pledgedLoans: ->
    filtered = _.filter @models, (loan)-> loan.getPledge() > 0
    sorted = _.sortBy filtered, (loan)-> 100000000 - loan.getPledge()

  loansWithNoPledge: ->
    filtered = _.filter @models, (loan)-> not loan.getPledge()

  pledgeOrder: (id)->
    modelIds = _.pluck @pledgedLoans(), 'id'
    _.indexOf modelIds, id

  recentLoans: ->
    @where {isRecent: true}

  recentCount: ->
    (@where {isRecent: true}).length

  filteredCollection: (term)->
    loansToSearch = @loansWithNoPledge()
    if term
      _.filter loansToSearch, (m)->
        m.matches(term)
    else loansToSearch

  # pull out the loan array in the JSON as it arrives
  parse: (resp)->
    @page++
    console.log 'incoming: ',resp.loans
    # remove any loans that have already been loaded
    loans = _.reject resp.loans, (l)=> l.id in _.pluck(@models,'id')
    
    for l in loans 
      l.pledge = 0
      l.postedMoment = moment(l.posted_date).valueOf()

      # mark the loan as recent if the posted_date is later
      # than the latest load time
      if l.postedMoment >= @latestLoad then l.isRecent = true
    
    console.log 'filtered/parsed: ', loans
    loans

class LoansList extends Backbone.View
  
  className: 'loansList'
  tagName: 'div'

  initialize: ->
    @searchTerm = ''

    # on fetch or reload, re-render the view
    @collection.on 'reset', =>
      @render()

    @collection.on 'add', (m)=>
      console.log 'added: ',m
      if m.get('isRecent') then @updateRecentCount()
      else @addLoanView(m) 

    @collection.on 'remove', (m)=>
      m.view.remove()

    @collection.on 'pledge:save', (m)=>
      @collection.sort {silent: true}
      @renderPledges()

      

  #template in coffeescript via coffeekup
  template: ->
    table class:'table table-bordered', ->
      tbody class:'pledges', ->
        tr -> td colspan:4, -> div id:'pl'

    div class:'alert alert-info recentCount', ->
    
    table class:'table table-bordered', ->
      tbody class:'loans', ->
      tfoot class:'progress-container',->

  updateRecentCount: ->
    console.log newCount = @collection.recentCount()
    @$('.recentCount').text "#{ newCount } new loans were posted. Click here to view them."
    @$('.recentCount').fadeIn().click =>
      @$('.recentCount').fadeOut()
      @addNewLoans()

  
  addNewLoans: ->
    for loan in @collection.recentLoans()
      @addLoanView(loan)

  render: ->
    console.log 'this obj',@
    @$el.html ck.render @template

    # create a view for each loan in the loan list
    @addLoanView(loan) for loan in @collection.models
    
    @$('.pledges').waypoint (ev,direction)=>
      console.log 'wp',direction
      @trigger 'pledge:scrollPast', direction

    @addScrollTrigger()
    @


  # fetches the next page of results (for older loans)
  loadMore: ->
    @collection.fetch({add: true, data: {page: @collection.page}})
    @addScrollTrigger()

  scrollTriggerTemplate: ->
    tr ->
      td colspan:4, ->
        div id:'more',class:'progress progress-success progress-striped active', ->
          div class:'bar',style:'width: 100%'
  
  # add a trigger for lazy loading
  addScrollTrigger: ->

    @$('tfoot.progress-container').html ck.render @scrollTriggerTemplate
    @$('tfoot.progress-container').click =>
      @loadMore()
    ###
    wait 1000, =>
      @$('#more').waypoint('destroy')
      $.waypoints('refresh')
      
      # lazy load older loans on scroll to bottom of page
      @$('#more').waypoint => 
        @loadMore()
      , { 'offset': '100%' }
    ###

  

  renderPledges: ->
    @$('.pledges').html ''
    @addLoanView(pledge) for pledge in @collection.pledgedLoans()
    @

  renderLoans: ->
    @$('.loans').html ''
    @addLoanView(loan) for loan in @collection.filteredCollection(@searchTerm)
    @

  doSearch: (@searchTerm)->
    @renderLoans()

  # adds a new Loan View and renders it inside this view
  addLoanView: (loan)->
    v = loan.view  ?= (new LoanView {model: loan}).remove()
    v.render()
    
    if loan.getPledge()
      v.$el.appendTo @$('.pledges')

    else if loan.matches(@searchTerm)

      if loan.get('isRecent')
        v.$el.prependTo @$('.loans')
        v.$el.addClass('hl')
        wait 1000, -> loan.view.$el.removeClass('hl')
        loan.set 'isRecent', false

      else
        v.$el.appendTo @$('.loans')

    v.delegateEvents()

    # gather events from the loan views and trigger them from this view
    loan.view.on 'all', (event,data)=>
      console.log 'bubbling',event,data
      @trigger event,data
    

class LoanView extends Backbone.View
  
  className: 'loanView'
  tagName: 'tr'

  initialize: ->
    @model.on 'error', (error)=>
      console.log 'model error'
      @$('.pledge-control').removeClass('success').addClass('error')
      @$('.with-help-suffix').hide()

    @model.on 'change', (m)=>
      console.log 'model changed'
      @updateProgress()

  template: ->
    td class:'main-info', ->
      div class:'location', ->
        div "#{@loan.get('location').country}"
        img class:'flag', src: "#{@loan.flagImage()}"
      div class:'profile-icon', ->
        img src:"#{ @loan.profileImage() }"
      div class:'info', ->
        div class:'name', "#{@loan.get 'name'}"
        div class:'activity', "#{@loan.get 'activity'}"
        div class:'use', "#{@loan.get 'use'}"

    td class: 'needed', "$ #{@loan.get 'loan_amount'}"

    td class:'status', ->
      div ->
        span class:'perc-funded', "#{@loan.percFunded()} %"
        span class:'funded', ->
          div 'funded so far'
          div class:'with-help-suffix', 'with your help!'
      div class:'progress progress-success', ->
        div class:'bar', style:"width: #{@loan.percFunded()}%;"

    td class:'pledge-area', ->
      div class:"control-group pledge-control#{ if @loan.getPledge() then ' success' else ''}", ->
        div class:'control', ->
          div class:'input-prepend input-append', ->
            span class:'add-on', '$'
            input type:'text', class:'pledge span2', size:'24', value: @loan.getPledge() ? '', placeholder:'your pledge'

  events:
    'keyup .pledge': 'update'
    'change .pledge': 'saveChange'


  updateProgress: ->
    funded = @model.percFunded(@model.getPledge())
    @$('.perc-funded').text "#{ funded } %"
    @$('.progress .bar').width "#{ funded }%"
    @$('.pledge-control').removeClass('error')
    if @model.getPledge() 
      @$('.with-help-suffix').show()
      @$('.pledge-control').addClass('success')
    else
      @$('.with-help-suffix').hide()
      @$('.pledge-control').removeClass('success')

  update: (e)->
    prevVal = @model.getPledge()
    @model.set 'pledge', (@$('input.pledge').val() or 0)
    @model.lastChangeIsPositive = @model.getPledge() > prevVal

  saveChange: (e)->
    if $('.pledge-control').hasClass('error')
      $('.pledge-control').removeClass('error')
      @$('.pledge').val('')
    else
      if not @model.getPledge() then @$('.pledge').val('')
      if @model.lastChangeIsPositive 
        @trigger 'message', { 
          message: '<strong>Thank you!</strong>'
          timeout: 2000
          type:'success'
        }
      @model.collection.trigger 'pledge:save', @model

  render: ->
    @$el.html ck.render @template, {loan: @model}
    @updateProgress()
    @

# view for the top nav bar
class TopBar extends Backbone.View
  el: '.navbar-fixed-top'

  events:
    'keyup .search': 'searchKeyPress'
    'click .pledges-header': -> $('body').scrollTop -50
      

  searchKeyPress: (e)->
    search = => @trigger 'search', $(e.target).val()
    
    # clear the previous timeout for search
    clearTimeout @searchTimeout
    
    # on return key, go ahead and search
    if e.which is 13 then search()

    # if another key, wait half a sec then search
    else @searchTimeout = wait 500, => search()

  updatePledgeTotal: (newAmount)->
    @$('.pledge-total').text newAmount
    @
  
  # show/hide the 'jump to pledges' link depending
  # on whether the user can see them
  togglePledgeLink: (direction)->
    if direction is 'up' then @$('.pledge-link').hide() else @$('.pledge-link').show()

  message: (message)->
    template = ->
      div class:"alert#{ if @msg.type then ' alert-'+@msg.type else '' }", ->
        if @msg.close
          a href:'#', 'data-dismiss':'alert',class:'close', "&times;"
        text @msg.message

    msgEl = @$('.messageArea')
    msgEl.html ck.render template, {msg: message}
    if message.timeout then wait message.timeout, => @$('.alert').fadeOut 'fast', => @$('.alert').remove()


class Router extends Backbone.Router
  initialize: ->

    # collection for loans
    @loans = new Loans()
    
    # views
    @topBar = new TopBar()
    @loansList = new LoansList({collection: @loans})   

    # normally I'd boostrap them, 
    # but here we're dealing with json via ajax only
    @loans.fetch()

    # event handlers to tie together interaction between
    # the two views

    @loans.on 'update:pledgeTotal', (newVal)=>
      @topBar.updatePledgeTotal(newVal)

    @loansList.on 'pledge:scrollPast',(direction)=>
      @topBar.togglePledgeLink(direction)

    @topBar.on 'search', (term)=>
      @loansList.doSearch(term)

  routes:
    '':'home'

  home: ->
    @loansList.render().open()


# for client side template rendering
w.ck = CoffeeKup

# using a router object for app/controller
w.app = new Router()

$ ->
  Backbone.history.start()
  
  