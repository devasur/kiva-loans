doctype 5
html lang:'en', ->
  head ->
    meta charset:'utf-8'
    meta name:"viewport", content:"width=device-width, initial-scale=1.0"
    link rel:'stylesheet', href:'/css/bootstrap.css'
    link rel:'stylesheet', href:'/css/bootstrap-responsive.css'
    link rel:'stylesheet', href:'/css/docs.css'

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
                li class:'my-pledges', -> a href:'', 'Your pledges'
                li class:'find-loans',-> a href:'', 'Find loans'
              span class:'pledges-header', ->
                button class:'btn btn-warning btn-small submit-pledges', ->
                  h3 'submit'
              span class:'label label-success pledge-link', '&uarr; jump up to your pledges'
              span class:'label label-info new-loans', '&uarr; new loans have arrived'
        a id:'my-pledges', ''
        div class:'row pledges-list', ->
        div id:'find-loans', ''
        div class:'row search-bar-cont', ->
          div class:'search-bar', ->
        div class:'row loans-list', ->
      div class:'modal hide fade', id:'thanks', ->
        div class:'modal-header', -> h3 'Thank you for helping!'
        div class:'modal-body', ->
          a class:'btn btn-info',href:'http://requestb.in/1kggro81?inspect',target:'_blank', 'Here is your receipt: http://requestb.in/1kggro81?inspect'
        div class:'modal-footer', -> a href:'#', class:'btn btn-success', 'data-dismiss':'modal', 'browse more loans'

    script src:'/js/utils.js', type:'text/javascript'
    script src:'/js/bootstrap.min.js', type:'text/javascript'
    script src:'/js/waypoints.min.js', type:'text/javascript'
    script src:'/js/ck.js', type: 'text/javascript'
    script src:'/js/client.js', type: 'text/javascript'
