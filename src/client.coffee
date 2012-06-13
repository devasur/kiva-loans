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
      @collection.trigger 'update:pledgeTotal', @collection.pledgeCount(), @collection.pledgeTotal()

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
    ok = /(''|^[0-9]+$)/.test(attrs.pledge)
    return 'not a number' unless ok

  # test if loan matches a search term
  matches: (term)->
    re = RegExp term, 'gi'
    fieldsToSearch = (@get('name')+@get('activity')+@get('use')+@get('location').country)
    re.test fieldsToSearch


class Loans extends Backbone.Collection
  model: Loan
  url: 'http://api.kivaws.org/v1/loans/newest.json'

  initialize: ->
    # keep track of the lastest loaded loan post_date
    @latestLoad = moment().valueOf()
    # ...and the last page loaded
    @page = 1

    @searchTypeAheadTerms = []

    # fetch newest loans every 10 seconds
    checkForNewLoans = doEvery 10000, => @fetch({add:true})

  # keep these sorted by the posted_date
  comparator: (loan)->
    1/parseInt(loan.get('postedMoment'),10)

  # total of current pledges
  pledgeTotal: ->
    _.reduce @models, (runningTotal, loan)-> 
      runningTotal + loan.getPledge()
    ,0

  pledgeCount: ->
    @pledgedLoans().length

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
    # remove any loans that have already been loaded
    console.log 'loading more...'
    loans = _.reject resp.loans, (l)=> l.id in _.pluck(@models,'id')
    keywords = []
    
    for l in loans 
      l.pledge = 0
      l.postedMoment = moment(l.posted_date).valueOf()
      
      # gather keyword for the search typeahead along the way
      keywords.push l.sector, l.activity, l.name, l.location.country
      
      # mark the loan as recent if the posted_date is later
      # than the latest load time
      if l.postedMoment >= @latestLoad then l.isRecent = true
    
    @searchTypeAheadTerms = _.union(_.compact(keywords),@searchTypeAheadTerms)
    @trigger 'search:typeahead',@searchTypeAheadTerms 
    loans
  
  submit: (cb)->
    myPledges = ({loanId: p.get('id'), amount: p.get('pledge')} for p in @pledgedLoans())
    $.post '/reqBin/1kggro81', {pledges: myPledges}, (resp)->
      cb(resp)

  clearPledges: ->
    for l in @models
      l.set('pledge',0)
      l.collection.trigger 'pledge:save', l
      

class LoansList extends Backbone.View
  
  className: 'container loansList'
  tagName: 'div'

  initialize: ->
    @searchTerm = ''

    # on fetch or reload, re-render the view
    @collection.on 'reset', =>
      @render()

    @collection.on 'add', (m)=>
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
        tr -> th colspan:4, -> h4 id:'pl', 'Pledge a loan to these partners by entering amounts to the right of their requests.'

    div class:'alert alert-info recentCount', ->
    
    table class:'table table-bordered', ->
      tbody class:'loans', ->
      tfoot class:'progress-container',->

  updateRecentCount: ->
    newCount = @collection.recentCount()
    @$('.recentCount').text "#{ newCount } new loans were posted. Click here to view them."
    @$('.recentCount').fadeIn().click =>
      @$('.recentCount').fadeOut()
      @addNewLoans()
    $('.new-loans').show()

  
  addNewLoans: ->
    for loan in @collection.recentLoans()
      @addLoanView(loan)

  render: ->
    @$el.html ck.render @template

    # create a view for each loan in the loan list
    @addLoanView(loan) for loan in @collection.models
    
    @$('.pledges').waypoint (ev,direction)=>
      @trigger 'pledge:scrollPast', direction

    @$('.recentCount').waypoint (ev,direction)=>
      if @$('.recentCount').is(':visible')
        @trigger 'newLoans:scrollPast', direction

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

    @$('.progress-container').html ck.render @scrollTriggerTemplate
    ###
    @$('.progress-container').click =>
      @loadMore()
    ###
    
    # lazy loading of results
    wait 1000, =>
      @$('#more').waypoint('destroy')
      $.waypoints('refresh')
      
      # lazy load older loans on scroll to bottom of page
      @$('#more').waypoint => 
        @loadMore()
      , { 'offset': '100%' }

  

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
      @trigger event,data
    

class LoanView extends Backbone.View
  
  className: 'loanView'
  tagName: 'tr'

  initialize: ->
    @model.on 'error', (error)=>
      @$('.pledge-control').removeClass('success').addClass('error')
      @$('.with-help-suffix').hide()

    @model.on 'change', (m)=>
      @updateProgress()

  template: ->
    td class:'main-info', ->
      div class:'info-cont', ->
        div class:'location', ->
          img class:'flag', src: "#{@loan.flagImage()}"
          div "#{@loan.get('location').country}"
        div class:'profile-icon', ->
          img src:"#{ @loan.profileImage() }"
        div class:'info', ->
          div class:'name', "#{@loan.get 'name'}"
          div class:'activity', "#{@loan.get 'activity'}"
          div class:'use', "#{@loan.get 'use'}"
      div class:'time-posted', ->
        em "posted #{moment(@loan.get('postedMoment')).fromNow()}"

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
    @model.set 'pledge', (@$('input.pledge').val() or 0)

  saveChange: (e)->
    if $('.pledge-control').hasClass('error')
      $('.pledge-control').removeClass('error')
      @$('.pledge').val('')
    else
      if not @model.getPledge() then @$('.pledge').val('')
      @model.collection.trigger 'pledge:save', @model

  render: ->
    @$el.html ck.render @template, {loan: @model}
    @updateProgress()
    @

# view for the top nav bar
class TopBar extends Backbone.View
  el: '.navbar-fixed-top'

  initialize: ->

  events:
    'keyup .search': 'searchKeyPress'
    'click .pledge-link': -> $('body').scrollTop -50
    'click .new-loans': -> $('body').scrollTop ($('.recentCount').scrollTop() - 50)
    'click .submit-pledges': -> @trigger 'submit'
      

  searchKeyPress: (e)->
    search = => @trigger 'search', $(e.target).val()
    
    # clear the previous timeout for search
    clearTimeout @searchTimeout
    
    # on return key, go ahead and search
    if e.which is 13 then search()

    # if another key, wait half a sec then search
    else @searchTimeout = wait 500, => search()

  updatePledgeTotal: (newCount,newAmount)->
    if newCount is 0 then @$('.pledges-header').slideUp() else @$('.pledges-header').slideDown()
    @$('.submit-pledges h3').text "Submit #{newCount} pledge#{ if newCount > 1 then 's' else ''} totalling $ #{newAmount}"
    @
  
  # show/hide the 'jump to pledges' link depending
  # on whether the user can see them
  togglePledgeLink: (direction)->
    if direction is 'up' then @$('.pledge-link').hide() else @$('.pledge-link').show()

  toggleNewLoansLink: (direction)->
    if direction is 'up' then @$('.new-loans').hide() else @$('.new-loans').show()

  message: (message)->
    template = ->
      div class:"alert#{ if @msg.type then ' alert-'+@msg.type else '' }", ->
        if @msg.close
          a href:'#', 'data-dismiss':'alert',class:'close', "&times;"
        text @msg.message

    msgEl = @$('.messageArea')
    msgEl.html ck.render template, {msg: message}
    if message.timeout then wait message.timeout, => @$('.alert').fadeOut 'fast', => @$('.alert').remove()

  showThanks: (cb)->
    $('#thanks').modal('show').on 'shown', cb

  loadTypeAhead: (keywords)->
    $('input.search').typeahead {source: keywords} 



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

    @loans.on 'update:pledgeTotal', (newCount,newVal)=>
      @topBar.updatePledgeTotal(newCount,newVal)

    @loans.on 'search:typeahead', (newKeywords)=>
      @topBar.loadTypeAhead(newKeywords)

    @loansList.on 'pledge:scrollPast',(direction)=>
      @topBar.togglePledgeLink(direction)
    @loansList.on 'newLoans:scrollPast',(direction)=>
      @topBar.toggleNewLoansLink(direction)

    @topBar.on 'search', (term)=>
      @loansList.doSearch(term)

    @topBar.on 'submit', =>
      @loans.submit (resp)=>
        @topBar.showThanks =>
          @loans.clearPledges()



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
  
  
