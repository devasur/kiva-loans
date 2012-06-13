doctype 5
html lang:'en', ->
  head ->
    meta charset:'utf-8'
    meta name:"viewport", content:"width=device-width, initial-scale=1.0"
    link rel:'stylesheet', href:'/css/bootstrap.css'
    link rel:'stylesheet', href:'/css/index.css' 

  body ->
    div class:'container main', ->
      div class:'navbar navbar-fixed-top', ->
        div class:'navbar-inner', ->
          div class: 'container', ->
            a class:'brand', href:'#', ->
              img src:'http://l3-1.kiva.org/rgitc4f74bc5741fa37924bcec931446088f7bfdaee1/img/logo/kiva.png'
            input type:'text', class:'search span2', placeholder:'search loans'
            span class:'pledges-header', ->
              div ->
                h2 'Your pledges total: $'
                h2 class:'pledge-total', '0'
              div ->
                span class:'label label-success pledge-link', '&uarr; go there'
            div class:'messageArea'
    
    script src:'/js/utils.js', type:'text/javascript'
    script src:'/js/bootstrap.min.js', type:'text/javascript'
    script src:'/js/waypoints.min.js', type:'text/javascript'
    script src:'/js/ck.js', type: 'text/javascript'
    script src:'/js/client.js', type: 'text/javascript'
