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

    @on 'pledge:save', =>
      window.localStorage.setItem 'kivaPledges', JSON.stringify @pledgesToSave()



  # get pledges from localStorage
  restorePledges: (cb)->
    prevPledges = JSON.parse localStorage?.getItem('kivaPledges') ? []
    #console.log(prevPledges)
    if prevPledges.length
      oldUrl = @url
      @url = "http://api.kivaws.org/v1/loans/#{ _.keys(prevPledges).join(',') }.json"
      console.log @url
      @fetch {
        add:true
        success: =>
          for loan in @models
            loan.set 'pledge', prevPledges[loan.id]
          @url = oldUrl
          cb()
      }
    else cb()


  # keep these sorted by the posted_date
  comparator: (loan)->
    1 - loan.getPledge()

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


  pledgesToSave:->
    pledges = {}
    pledges[p.id] = p.getPledge() for p in @pledgedLoans()
    pledges

  loansWithNoPledge: ->
    filtered = _.filter @models, (loan)-> not loan.getPledge()

  pledgeOrder: (id)->
    modelIds = _.pluck @pledgedLoans(), 'id'
    _.indexOf modelIds, id

  recentLoans: ->
    @where {isRecent: true}

  recentCount: ->
    (@where {isRecent: true}).length

  filteredCollection: (@term)->
    loansToSearch = @loansWithNoPledge()
    if @term
      _.filter loansToSearch, (m)->
        m.matches(@term)
    else loansToSearch

  # pull out the loan array in the JSON as it arrives
  parse: (resp)->
    console.log @url, resp
    @page++
    # remove any loans that have already been loaded
    console.log 'loading more...'
    loans = _.reject resp.loans, (l)=> l.id in _.pluck(@models,'id')

    keywords = []
    
    for l in loans 
      l.pledge = 0
      l.postedMoment = moment(l.posted_date).valueOf()
      
      # gather keyword for the search typeahead along the way
      keywords.push l.sector, l.activity
      
      # mark the loan as recent if the posted_date is later
      # than the latest load time
      if l.postedMoment >= @latestLoad then l.isRecent = true
    
    @searchTypeAheadTerms = _.union(_.compact(keywords),@searchTypeAheadTerms)
    
    @trigger 'search:addToTypeAhead',@searchTypeAheadTerms 

    loans
  
  submit: (cb)->
    myPledges = ({loanId: p.get('id'), amount: p.get('pledge')} for p in @pledgedLoans())
    #console.log myPledges
    $.post '/reqBin/1kggro81', {pledges: myPledges}, (resp)->
      cb(resp)

  clearPledges: ->
    for l in @models
      l.set('pledge',0)
      l.collection.trigger 'pledge:save', l

  getBorrowerInfo: ->
    wait 250, =>
      loansToDo = (@filter (l)-> not l.get('borrowerInfo')?)
      #console.log loansToDo
      if loansToDo.length
        firstTenIds = _.pluck _.first(loansToDo,10), 'id'
        url = "http://api.kivaws.org/v1/loans/#{ firstTenIds }.json"
        $.get url, (resp)=>
          #console.log resp.loans
          loans = resp.loans
          for loan in loans
            @get(loan.id).set('borrowerInfo',loan.description.texts?.en ? '')
          @getBorrowerInfo()




      

class LoansList extends Backbone.View
  
  el: '.loans-list'

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
      

  #template in coffeescript via coffeekup
  template: ->

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
    @addLoanView(loan) for loan in @collection.loansWithNoPledge()

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
    
    # lazy loading of results
    @$('#more').waypoint('destroy')
    $.waypoints('refresh')
    
    wait 1000, =>
      # lazy load older loans on scroll to bottom of page
      @$('#more').waypoint => 
        @loadMore()
      , { 'offset': '100%' }


  doSearch: (@searchTerm)->
    @renderLoans()

  # adds a new Loan View and renders it inside this view
  addLoanView: (loan)->
    v = loan.view  ?= (new LoanView {model: loan}).remove()
    v.render()

    if loan.get('isRecent')

      v.$el.prependTo @$('.loans')
      v.$el.addClass('hl')
      wait 1000, -> loan.view.$el.removeClass('hl')
      loan.set 'isRecent', false

    else
      v.$el.appendTo @$('.loans')

    v.delegateEvents()



class BorrowerInfoView extends Backbone.View

class LoanView extends Backbone.View
  
  className: 'loan-view'
  tagName: 'tr'

  initialize: ->
    @model.on 'error', (error)=>
      @$('.pledge-control').removeClass('success').addClass('error')
      @$('.with-help-suffix').hide()

    @model.on 'change', (m)=>
      @updateProgress()

    @model.on 'change:borrowerInfo', (m)=>
      console.log 'linking popup'
      @$('.pop').fadeIn()

  template: ->
    td class:'main-info', ->
      div class:'info-cont', ->
        div class:'location', ->
          #img class:'flag', src: "#{@loan.flagImage()}"
          div "#{@loan.get('location').country}"
        div class:'profile-icon', ->
          img src:"#{ @loan.profileImage() }"
        div class:'info', ->
          span class:'name', "#{@loan.get 'name'}"
          span class:'pop', ->
            i class:'icon-info-sign'
          div class:'activity', "#{@loan.get 'sector'}: #{@loan.get 'activity'}"
          div class:'use', "#{@loan.get 'use'}"
      div class:'time-posted', ->
        em "posted #{moment(@loan.get('postedMoment')).fromNow()}"

    td class: 'needed', "$ #{@loan.get 'loan_amount'}"

    td class:'status', ->
      div ->
        span class:'perc-funded', "#{@loan.percFunded()} %"
        span class:'funded', ->
          div "funded#{ if @loan.percFunded() is 100 then ' so far' else ''}"
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


class PledgesList extends Backbone.View
  el: '.pledges-list'

  template: ->
    table class:'table table-bordered', ->
      tbody class:'pledges', ->
        #tr -> th colspan:4, -> h4 id:'pl', 'Pledge a loan to these partners by entering amounts to the right of their requests.'

  render: ->
    @$el.html ck.render @template
    for pledge in @collection.pledgedLoans()
      pledge.view.render().$el.appendTo @$('.pledges')
    @

# view for the top nav bar
class TopBar extends Backbone.View
  el: '.navbar-fixed-top'

  initialize: ->

    $('#my-pledges').waypoint (ev,direction)=>
      if direction is 'up' then @navChoose('my-pledges')

    $('#find-loans').waypoint (ev,direction)=>
      @navChoose('find-loans')

  navChoose: (item)->
    $('#myNav li').removeClass 'active'
    $("#myNav li.#{item}").addClass 'active'

  refreshScroll: ->
    $.waypoints('refresh')

  events:
    'click li.my-pledges a': -> 
      $('body').scrollTop -50
      @navChoose('my-pledges')
    'click li.find-loans a': -> 
      @navChoose('find-loans')
      $('body').scrollTop ($('#find-loans').offset().top - 85)
      $('.search').focus()
    'click .submit-pledges': -> @trigger 'submit'
      

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

class SearchView extends Backbone.View
  el: '.search-bar'
  keywords: {}

  initialize: ->

  template: ->
    a id:'yo'
    div class:'navbar sub', ->
      div class:'navbar-inner', ->
        div class:'container', ->
          form class:'navbar-form pull-left', ->
            div class:'control-group', ->
              div class:'input-prepend', ->
                span class:'add-on', -> 
                  i class:'icon-search'
                input type:'text', placeholder:'search kiva loans', class:'span2 search search-query typeahead'
            span class:'txt', 'that are'
            div class:'btn-group status', ->
              button class:'btn dropdown-toggle', 'data-toggle':'dropdown', ->
                span class:'text', 'still raising funds '
                span class:'caret'
              ul class:'dropdown-menu', ->
                li -> a 'data-value':'fundraising', 'still raising funds'
                li -> a 'data-value':'funded', 'funded'
                li -> a 'data-value':'almost funded', 'almost funded'
            span class:'txt', 'from'
            div class:'btn-group gender', ->
              button class:'btn dropdown-toggle', 'data-toggle':'dropdown', ->
                span class:'text', 'women and men '
                span class:'caret'
              ul class:'dropdown-menu', ->
                li -> a 'data-value':'female', 'women only'
                li -> a 'data-value':'male', 'men only'
                li -> a 'data-value':'', 'women and men'
            


  events:
    'change input.search':'search'
    'click .gender a': 'setGender'
    'click .status a': 'setStatus'
      

  setGender: (e)->
    @options.gender = $(e.target).data('value')
    @$('.gender .text').text $(e.target).text()+' '
    @search()

  setStatus: (e)->
    @options.status = $(e.target).data('value')
    @$('.status .text').text $(e.target).text()+' '
    @search()


  search: ->
    @trigger 'search', @makeUrl()
    

  allKeywords: ->
    _.flatten _.values @keywords

  makeUrl: ->
    url = "http://api.kivaws.org/v1/loans/search.json?q=#{ @$('.search').val() }"
    url += if @options.gender then "&gender=#{ @options.gender }" else ''
    url += if @options.status in ['funded','fundraising'] then "&status=#{ @options.status }" else ''
    url += if @options.status is 'almost funded' then "&sortby=amount_remaining" else ''
    console.log url
    url

  resetTypeAhead: ->
    #console.log 'setting typeahead source: ',@allKeywords()
    @$('input.search').typeahead {source: @allKeywords()}

  render: ->
    @$el.html ck.render @template
    @$('#yo').waypoint (e,direction)->
      #console.log 'wp'
      if direction is 'down'
        $('.search-bar .navbar').addClass('fixed')
      else
        $('.search-bar .navbar').removeClass('fixed')
    , { offset: 65 }
    @


class Partner extends Backbone.Model

class Partners extends Backbone.Collection
  model: Partner
  url: 'http://api.kivaws.org/v1/partners.json'
  keywords: {}

  parse: (resp)->
    resp.partners

  allCountries: ->
    @keywords.countries ?= _.uniq _.pluck _.flatten(@pluck('countries')), 'name'

  allRegions: ->
    @keywords.regions ?= _.uniq _.pluck _.flatten(@pluck('countries')), 'region'

  allNames: ->
    @keywords.names ?= @pluck 'name'




class Router extends Backbone.Router
  
  eventController: ->

    # event handlers to tie together interaction between
    # the two views

    @loans.on 'update:pledgeTotal', (newCount,newVal)=>
      @topBar.updatePledgeTotal(newCount,newVal)

    @loans.on 'pledge:save', (p)=>
      console.log 'saved: ',p
      @pledgeList ?= new PledgesList {collection: @loans}
      @pledgeList.render()

    @loans.on 'search:addToTypeAhead', (keywords)=>
      #@searchBar.keywords.tags = _.union (@searchBar.keywords.tags ?= []), keywords
      #@searchBar.resetTypeAhead()


    @pledgesList.on 'pledge:scrollPast',(direction)=>
      @topBar.togglePledgeLink(direction)
    
    @loansList.on 'newLoans:scrollPast',(direction)=>
      @topBar.toggleNewLoansLink(direction)


    @topBar.on 'submit', =>
      @loans.submit (resp)=>
        @topBar.showThanks =>
          @loans.clearPledges()

    @searchBar.on 'search', (url)=>
      @loans.url = url
      @loans.page = 1
      @loans.fetch {
        success: => #console.log @loans
      }


  routes:
    '':'home'

  home: ->
    @topBar = new TopBar()
    @searchBar = new SearchView()
    @searchBar.render()
    @loans = new Loans()
    @partners = new Partners()
    @loansList = new LoansList {collection: @loans}
    @pledgesList = new PledgesList {collection: @loans}

    @loans.restorePledges =>
      @pledgesList.render()
      @loans.fetch {
        add: true
        success: =>
          @loans.getBorrowerInfo()
          @loansList.render()
          @topBar.refreshScroll()
      }

    @partners.fetch {
      success: =>
        _.extend @searchBar.keywords, {
          countries: @partners.allCountries()
          regions: @partners.allRegions()
          partners: @partners.allNames()
        }
        @searchBar.resetTypeAhead()
    }

    @eventController()

    
    


# for client side template rendering
w.ck = CoffeeKup

# using a router object for app/controller
w.app = new Router()

$ ->
  Backbone.history.start()
  
  
