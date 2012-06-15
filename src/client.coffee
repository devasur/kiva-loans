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

  profileImageLarge: ->
    "http://www.kiva.org/img/s300/#{@get('image').id}.jpg"
  
  countryCode: ->
    @get('location').country_code

  # calculate the percent the loan is funded
  percFunded: (withHelp = 0)->
    Math.floor (@get('funded_amount')+withHelp)*100/@get('loan_amount')

  # get the integer value for the current pledge
  pledge: ->
    parseInt @get('pledge'), 10

  # get full sector: activity label
  sectorActivity: ->
    "#{ if (sector = @get('sector') )isnt (activity = @get('activity')) then (sector+': ') else ''}#{activity}"

  latLong: ->
    @get('location').geo.pairs.split ' '

  # linking borrowers to their partner info
  partner: ->
    app.partners.get(@get('partner_id'))

  pDelinquency: ->
    dr = @partner().get('delinquency_rate')
    (Math.round (dr*10))/10

  pDefault: ->
    dr = @partner().get('default_rate')
    (Math.round (dr*10)/10)

  place: ->
    "#{ if (town = @get('location').town) then (town+', ') else ''}#{@get('location').country}" 


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

    # save the cart in local storage in case user leaves the page
    @on 'pledge:save', =>
      window.localStorage.setItem 'kivaPledges', JSON.stringify @pledgesToSave()



  # get pledges from localStorage
  restorePledges: (cb)->
    if window.localStorage.kivaPledges
      prevPledges = JSON.parse localStorage?.getItem('kivaPledges')
      if _.keys(prevPledges).length
        oldUrl = @url
        @url = "http://api.kivaws.org/v1/loans/#{ _.keys(prevPledges).join(',') }.json"
        @fetch {
          add:true
          success: =>
            for loan in @models
              loan.set 'pledge', prevPledges[loan.id]
            @url = oldUrl
            cb()
        }
      else cb()
    else cb()


  # keep these sorted by the posted_date
  comparator: (loan)->
    1 - loan.pledge()

  # total of current pledges
  pledgeTotal: ->
    _.reduce @models, (runningTotal, loan)-> 
      runningTotal + loan.pledge()
    ,0

  pledgeCount: ->
    @pledgedLoans().length

  pledgedLoans: ->
    filtered = _.filter @models, (loan)-> loan.pledge() > 0
    sorted = _.sortBy filtered, (loan)-> 100000000 - loan.pledge()


  pledgesToSave:->
    pledges = {}
    pledges[p.id] = p.pledge() for p in @pledgedLoans()
    pledges

  loansWithNoPledge: ->
    filtered = _.filter @models, (loan)-> not loan.pledge()

  pledgeOrder: (id)->
    modelIds = _.pluck @pledgedLoans(), 'id'
    _.indexOf modelIds, id

  recentLoans: ->
    @where {isRecent: true}

  newCount: ->
    (@where {isRecent: true}).length

  filteredCollection: (@term)->
    loansToSearch = @loansWithNoPledge()
    if @term
      _.filter loansToSearch, (m)->
        m.matches(@term)
    else loansToSearch

  clearNonPledges: ->
    @remove @loansWithNoPledge()

  # pull out the loan array in the JSON as it arrives
  parse: (resp)->
    @page++
    # remove any loans that have already been loaded
    @resultsCount = resp.paging?.total ? 0
    @trigger 'update:resultsCount', @resultsCount
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
    myPledges = ({id: p.get('id'), amount: p.get('pledge')} for p in @pledgedLoans())
    $.post '/reqBin/1gvkakw1', {loans: myPledges}, (resp)->
      cb(resp)

  submitToBasket: ->
    myPledges = JSON.stringify ({id: p.get('id'), amount: p.get('pledge')} for p in @pledgedLoans())
    formEl = $('#submitToBasket')
    $(formEl).find('input[name="loans"]').val(myPledges)
    @clearPledges()
    wait 250, -> formEl[0].submit()

  clearPledges: ->
    for l in @models
      l.set('pledge',0)
      l.collection.trigger 'pledge:save', l

  getBorrowerInfo: ->
    wait 250, =>
      loansToDo = (@filter (l)-> not l.get('borrowerInfo')?)
      if loansToDo.length
        firstTenIds = _.pluck _.first(loansToDo,10), 'id'
        url = "http://api.kivaws.org/v1/loans/#{ firstTenIds }.json"
        $.get url, (resp)=>
          loans = resp.loans
          for loan in loans
            @get(loan.id).set('borrowerInfo',loan.description.texts?.en ? '')
          @getBorrowerInfo()


# all the partner info is loaded in the background
# and linked to the borrowers to access when available

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



# VIEWS

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
    'click li.find-loans': -> 
      @navChoose('find-loans')
      $('body').scrollTop ($('#find-loans').offset().top - 85)
      $('.search').focus()
    'click .submit-pledges': -> @trigger 'submit'
      

  # update or clear the pledge button info
  updatePledgeTotal: (newCount,newAmount)->
    if newCount is 0 then @$('.pledges-header').slideUp() else @$('.pledges-header').slideDown()
    @$('.submit-pledges h3').text "Submit #{newCount} pledge#{ if newCount > 1 then 's' else ''} totalling $ #{newAmount}"
    @

  # update or clear the new loan badge
  updateNewCount: (newCount)->
    if newCount is 0 then @$('.find-loans .badge').text('0').fadeOut()
    else @$('.find-loans .badge').fadeIn().text newCount
    @
  
  # show/hide the 'jump to pledges' link depending
  # on whether the user can see them

  toggleNewLoansLink: (direction)->
    if direction is 'up' then @$('.new-loans').hide() else @$('.new-loans').show()

  # decided not to use this
  message: (message)->
    template = ->
      div class:"alert#{ if @msg.type then ' alert-'+@msg.type else '' }", ->
        if @msg.close
          a href:'#', 'data-dismiss':'alert',class:'close', "&times;"
        text @msg.message

    msgEl = @$('.messageArea')
    msgEl.html ck.render template, {msg: message}
    if message.timeout then wait message.timeout, => @$('.alert').fadeOut 'fast', => @$('.alert').remove()

  loadTypeAhead: (keywords)->
    $('input.search').typeahead {source: keywords} 


# the basket of pledges
class PledgesList extends Backbone.View
  el: '.pledges-list'

  initialize: ->

    @collection.on 'pledge:save', =>
      @render()

    @collection.on 'remove', =>
      if @collection.pledgeCount() is 0
        @$('.intro th h4').text 'You currently have no pledges. Pledge a loan to these partners by entering amounts to the right of their requests.'
        @$('thead').show()

  template: ->
    table class:'table table-bordered', ->
      if @pledgeCount is 0
        thead class:'intro', -> 
          tr -> th colspan:4, -> h4 'Pledge a loan to these partners by entering amounts to the right of their requests.'
      tbody class:'pledges', ->

  render: ->
    @$el.html ck.render @template, { pledgeCount: @collection.pledgeCount() }
    for pledge in @collection.pledgedLoans()
      pledge.view.render().$el.appendTo @$('.pledges')
      pledge.view.delegateEvents()
    @


# the green search bar
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
            div class:'control-group search-container', ->
              div class:'input-prepend', ->
                span class:'add-on', ->
                  i class:'icon-search'
                  img class:'wait', src:'img/wait.gif'
                input type:'text', placeholder:'find kiva loans', class:'span2 search search-query typeahead'
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
          span class:'results-count pull-right', ''
            


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
    @$('.icon-search').hide()
    @$('img.wait').show()
    @trigger 'search', @makeUrl(), =>
      @$('.icon-search').show()
      @$('img.wait').hide()

  updateResultsCount: (newCount)->
    @$('.results-count').text "#{newCount} loans found"
    

  allKeywords: ->
    _.flatten _.values @keywords

  makeUrl: ->
    url = "http://api.kivaws.org/v1/loans/search.json?q=#{ @$('.search').val() }"
    url += if @options.gender then "&gender=#{ @options.gender }" else ''
    url += if @options.status in ['funded','fundraising'] then "&status=#{ @options.status }" else ''
    url += if @options.status is 'almost funded' then "&sortby=amount_remaining" else ''
    url

  resetTypeAhead: ->
    @$('input.search').typeahead {source: @allKeywords()}

  render: ->
    @$el.html ck.render @template
    @$('#yo').waypoint (e,direction)->
      if direction is 'down'
        $('.search-bar .navbar').addClass('fixed')
      else
        $('.search-bar .navbar').removeClass('fixed')
    , { offset: 65 }
    @

# the searchable loans list
class LoansList extends Backbone.View
  
  el: '.loans-list'

  initialize: ->
    @searchTerm = ''

    # on fetch or reload, re-render the view
    @collection.on 'reset', =>
      @render()

    @collection.on 'add', (m)=>
      if m.get('isRecent')
        @updateNewCount()
      else @addLoanView(m) 

    @collection.on 'remove', (m)=>
      m.view.remove()

      

  #template in coffeescript via coffeekup
  template: ->

    div class:'alert alert-info newCount', ->
    
    table class:'table table-bordered', ->
      tbody class:'loans', ->
      tfoot class:'progress-container',->

  # 
  updateNewCount: ->
    newCount = @collection.newCount()
    @$('.newCount').text "#{ newCount } new loans were posted. Click here to view them."
    @$('.newCount').fadeIn().click =>
      @$('.newCount').fadeOut()
      @addNewLoans()
      @collection.trigger 'update:newCount', 0

    @collection.trigger 'update:newCount', newCount
    

  
  addNewLoans: ->
    for loan in @collection.recentLoans()
      @addLoanView(loan)
      @trigger 'cleared:recentLoans'


  render: ->
    @$el.html ck.render @template

    # create a view for each loan (no pledge) in the loan list
    @addLoanView(loan) for loan in @collection.loansWithNoPledge()

    # for lazy loading
    @addScrollTrigger()
    @


  # fetches the next page of results (for older loans)
  loadMore: ->
    @collection.fetch {
      add: true
      data: {page: @collection.page}
      success: =>
        @collection.getBorrowerInfo()
    }
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

# view for each individual loan
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
      @$('.pop').fadeIn()
      @$('.more-info').text @model.get('borrowerInfo')
      @initBorrowerInfo()
      

  initBorrowerInfo: ->
    @$('.more-info-cont').fadeIn()
    @$('.profile-icon, .pop, .more-info-cont').addClass('active').click =>
      @borrowerInfoView.render()


  template: ->
    td class:'main-info', ->
      div class:'info-cont', ->
        div class:'location bob', ->
          i class:"#{ @loan.countryCode().toLowerCase() } flag"
          div "#{@loan.get('location').country}"
        div class:'profile-icon', ->
          img src:"#{ @loan.profileImage() }"
        div class:'info', ->
          span class:'pop', ->
            i class:'icon-info-sign icon-white'
          span class:'name', "#{@loan.get 'name'}"
          div class:'activity', "#{ @loan.sectorActivity() }"
          div class:'more-info-cont', ->
            div class:'more-info', "#{ @loan.get('borrowerInfo') ? '' }"
            div class:'label label-small read-more', 'read more &darr;'
      div class:'time-posted', ->
        em "posted #{moment(@loan.get('postedMoment')).fromNow()}"

    td ->
      div class:'needed', "$ #{@loan.get 'loan_amount'}"
      div class:'use', "#{@loan.get 'use'}"

    td class:'status', ->
      div ->
        span class:'perc-funded', "#{@loan.percFunded()} %"
        span class:'funded', ->
          div "funded#{ if @loan.percFunded() is 100 then ' so far' else ''}"
          div class:'with-help-suffix', 'with your help!'
      div class:'progress progress-success', ->
        div class:'bar', style:"width: #{@loan.percFunded()}%;"

    td class:'pledge-area', ->
      div class:"control-group pledge-control#{ if @loan.pledge() then ' success' else ''}", ->
        div class:'control', ->
          div class:'input-prepend input-append', ->
            span class:'add-on', '$'
            input type:'text', class:'pledge span2', size:'24', value: @loan.pledge() ? '', placeholder:'your pledge'

  events:
    'keyup .pledge': 'update'
    'change .pledge': 'saveChange'


  updateProgress: ->
    funded = @model.percFunded(@model.pledge())
    @$('.perc-funded').text "#{ funded } %"
    @$('.progress .bar').width "#{ funded }%"
    @$('.pledge-control').removeClass('error')
    if @model.pledge() 
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
      if not @model.pledge() then @$('.pledge').val('')
      @model.collection.trigger 'pledge:save', @model

  render: ->
    @$el.html ck.render @template, {loan: @model}
    @updateProgress()
    if @model.get('borrowerInfo') then @initBorrowerInfo()
    @borrowerInfoView = new BorrowerInfoView({model: @model})
    @locationInfoView = new WikiView({model: @model})

    @$('.location').click => 
      @locationInfoView.render()
    @


# popup for geography info
class WikiView extends Backbone.View
  className:'modal location-map'
  tagName:'div'


  template: ->
    div class:'modal hide','data-toggle':'modal', ->
      div class:'modal-header', ->
        h3 "#{ @loan.place() } "
      div class:'modal-body', ->
        iframe width:'100%', height:'100%', frameborder:'0',marginheight:'0',marginwidth:'0', src:"http://en.m.wikipedia.org/wiki/#{@loan.get('location').country}#firstHeading"
      div class:'modal-footer', ->
        a href:'#', class:'btn btn-success', 'data-dismiss':'modal', 'close'

  render: ->
    @$el.html ck.render @template, { loan: @model }
    @$el.appendTo('.main')
    @$('.modal').modal 'show'
    @

# detail popup for extra borrower info
class BorrowerInfoView extends Backbone.View
  className: 'borrower-info'
  tagName: 'div'

  template: ->
    div class:'modal hide','data-toggle':'modal', ->
      div class:'modal-header', ->
        h3 "#{ @loan.get('name')} "
      div class:'modal-body', ->
        img src:"#{ @loan.profileImageLarge() }"
        p "#{ @loan.get('borrowerInfo') }"
        div ->
          table class:'table', ->
            tr ->
              td 'Partner: '
              td "#{@partner.get('name')}"
            tr ->
              td 'Loans posted by partner:'
              td "#{@partner.get('loans_posted')}"
            tr ->
              td 'Delinquency rate: '
              td "#{@loan.pDelinquency()}"
            tr ->
              td 'Default rate:'
              td "#{@loan.pDefault()}"
            tr ->
              td 'Rating'
              td "#{@partner.get('rating')}"

      div class:'modal-footer', ->
        a href:'#', class:'btn btn-success', 'data-dismiss':'modal', 'close'

  render: ->
    @$el.html ck.render @template, { loan: @model, partner: @model.partner() }
    @$el.appendTo('.main')
    @$('.modal').modal 'show'
    @

# the thankyou popup on submission
class ThanksView extends Backbone.View
  className: 'modal hide fade'
  id: 'thanks'
  tagName: 'div'

  template: ->
      div class:'modal-header', -> h3 'Thank you for helping!'
      div class:'modal-body', ->
        h3 'Here is the receipt on requestb.in:'
        a class:'btn btn-info',href:'http://requestb.in/1gvkakw1?inspect',target:'_blank', 'http://requestb.in/1gvkakw1?inspect'
        h3 'Or... take it to a real, live Kiva Basket:'
        a class:'btn btn-warning submitToBasket', ->
          i class:'icon-shopping-cart icon-white'
          span 'take me there!'
      div class:'modal-footer', -> a href:'#', class:'btn btn-success', 'data-dismiss':'modal', 'browse more loans'

  render: ->
    @$el.html ck.render @template
    @$el.appendTo('.main')
    @$el.modal('show')
    $('#thanks .submitToBasket').click =>
      @trigger 'toBasket'
    @


# only one route, but using this for an event manager too
class Router extends Backbone.Router

  initialize: ->
    # initialize models, collections and views to be used
    @topBar = new TopBar()
    @searchBar = new SearchView()
    @loans = new Loans()
    @partners = new Partners()
    @loansList = new LoansList {collection: @loans}
    @pledgesList = new PledgesList {collection: @loans}
    @thanksView = new ThanksView()
  

  # setup event manager to tie 
  # together interaction between the views
  eventController: ->

    # pledge updates
    @loans.on 'update:pledgeTotal', (newCount,newVal)=>
      @topBar.updatePledgeTotal(newCount,newVal)

    @loans.on 'pledge:save', (p)=>
      @pledgeList ?= new PledgesList {collection: @loans}
      @pledgeList.render()


    # update counts in topbar and search bar
    @loans.on 'update:resultsCount', (newCount)=>
      @searchBar.updateResultsCount newCount

    @loans.on 'update:newCount', (newCount)=>
      @topBar.updateNewCount newCount

    @loans.on 'add:newLoans', ->
      @topBar.clearNewCount()


    # when the user clicks the big orange submit btn
    @topBar.on 'submit', =>
      @loans.submit (resp)=>
        @thanksView.render()

    @thanksView.on 'toBasket', =>
      @loans.submitToBasket()

    @searchBar.on 'search', (url, done)=>
      @loans.url = url
      @loans.page = 1
      @loans.clearNonPledges()
      @loans.fetch {
        add: true
        success: =>
          done()
          @loans.getBorrowerInfo()
          @loansList.addScrollTrigger()
      }

  # restore and show any pledges saved in 
  # localStorage
  restorePledges: ->
    @loans.restorePledges =>
      @pledgesList.render()
      @loans.fetch {
        add: true
        success: =>
          @loans.getBorrowerInfo()
          @loansList.render()
          @topBar.refreshScroll()
      }

  # get and organize autocomplete data 
  # from the partners collection
  populateTypeahead: ->
    @partners.fetch {
      success: =>
        _.extend @searchBar.keywords, {
          countries: @partners.allCountries()
          regions: @partners.allRegions()
          partners: @partners.allNames()
          sectors: ['Agriculture', 'Arts', 'Clothing', 'Construction', 'Education', 'Entertainment', 'Food', 'Health', 'Housing', 'Manufacturing', 'Personal Use', 'Retail', 'Services', 'Transportation', 'Wholesale']
        }
        @searchBar.resetTypeAhead()
    }

  # only one route for now!
  routes:
    '':'home'

  home: ->

    @restorePledges()
    @searchBar.render()
    @populateTypeahead()
    @eventController()

    

# for client side template rendering
w.ck = CoffeeKup

# using a router object for app/controller
w.app = new Router()
$ ->
  Backbone.history.start()
  
  
