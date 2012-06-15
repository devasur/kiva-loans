doctype 5
html lang:'en', ->
  head ->
    meta charset:'utf-8'
    meta name:"viewport", content:"width=device-width, initial-scale=1.0"
    link rel:'stylesheet', href:'/css/bootstrap.css'
    link rel:'stylesheet', href:'/css/bootstrap-responsive.css'
    link rel:'stylesheet', href:'/css/docs.css'
    link rel:'stylesheet', href:'/css/flags.css'

    link rel:'stylesheet', href:'/css/index.css' 

  body  ->
    div data-spy:'scroll', ->
      div class:'main container', ->
        div id: 'myNav', class:'navbar navbar-fixed-top', ->
          div class:'navbar-inner', ->
            div class: 'container', ->
              a class:'brand kiva', href:'#', ->
                img src:'http://l3-1.kiva.org/rgitc4f74bc5741fa37924bcec931446088f7bfdaee1/img/logo/kiva.png'
              ul class:'nav', ->
                li class:'my-pledges', -> 
                  a href:'', '&hearts; My pledges'
                li class:'find-loans',-> 
                  a href:'', '&infin; Find loans'
                  span class:'badge badge-info', ''
              span class:'pledges-header', ->
                button class:'btn btn-warning btn-small submit-pledges', ->
                  i class:'icon-shopping-cart icon-white'
                  h3 'submit'
        a id:'my-pledges', ''
        div class:'row pledges-list', ->
        div id:'find-loans', ''
        div class:'row search-bar-cont', ->
          div class:'search-bar', ->
        div class:'row loans-list', ->
      
      form id:'submitToBasket',action:'http://www.kiva.org/basket/set',method:'POST', ->
        input name:'loans',value:"",type:'hidden'
        input name:'donation',value:'0',type:'hidden'
        input name:'app_id',value:'us.pzzd.kiva',type:'hidden'

      

    script src:'/js/utils.js', type:'text/javascript'
    script type:"text/javascript", src:"http://maps.googleapis.com/maps/api/js?key=AIzaSyDcYD-ok5lkpCvOc9P70Bas4BfDqTSI5kA&sensor=false"
    script src:'/js/bootstrap.min.js', type:'text/javascript'
    script src:'/js/waypoints.min.js', type:'text/javascript'
    script src:'/js/ck.js', type: 'text/javascript'
    script src:'/js/client.js', type: 'text/javascript'
