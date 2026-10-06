import AppKit

enum AIChatTemplate {
    static func page(_ theme: Theme) -> String {
        let c = theme.chrome
        let css = """
        body{font-size:13px;line-height:1.5}
        main{max-width:none;margin:0;padding:10px 12px 24px}
        h1,h2,h3{font-size:1.05em;border:0;margin:.8em 0 .4em}
        code,pre{font-size:12px}
        pre{position:relative;padding:10px 12px;margin:.4em 0 .8em}
        .msg{margin:0 0 14px}
        .msg.user{background:\(PreviewTemplate.hex(c.bgRaised));border:1px solid \(PreviewTemplate.hex(c.border));border-radius:8px;padding:8px 10px}
        .msg.user .q{white-space:normal}
        .chips{display:flex;flex-wrap:wrap;gap:4px;margin-bottom:6px}
        .chip{font:11px "SF Mono",ui-monospace,Menlo,monospace;background:\(PreviewTemplate.hex(c.bgHover));color:\(PreviewTemplate.hex(c.textSecondary));border-radius:4px;padding:1px 6px}
        .tools{position:absolute;top:4px;right:6px;display:none;gap:4px}
        pre:hover .tools{display:flex}
        .tools button{font:11px -apple-system,sans-serif;background:\(PreviewTemplate.hex(c.bgOverlay));color:\(PreviewTemplate.hex(c.textPrimary));border:1px solid \(PreviewTemplate.hex(c.border));border-radius:4px;padding:1px 7px;cursor:pointer}
        .wait{color:\(PreviewTemplate.hex(c.textTertiary))}
        .err{color:\(PreviewTemplate.hex(c.error))}
        .caret{display:inline-block;width:7px;height:1em;vertical-align:text-bottom;background:\(PreviewTemplate.hex(c.accent));animation:blink 1s steps(1) infinite}
        @keyframes blink{50%{opacity:0}}
        a.loc{border-bottom:1px dotted \(PreviewTemplate.hex(c.accent))}
        .empty{color:\(PreviewTemplate.hex(c.textTertiary));padding:8px 2px}
        """
        return PreviewTemplate.page(theme).replacingOccurrences(of: "</style>", with: css + "</style>")
    }

    static let script = """
    var rideLoc=/(^|[\\s(`'"])((?:[\\w.-]+\\/)*[\\w.-]+\\.(?:rs|c|h|cc|cpp|cxx|hh|hpp|hxx|toml|md|cmake|mk|txt)):(\\d+)/g;
    function rideLinkify(root){
      var walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT,null),nodes=[],n;
      while((n=walker.nextNode())){if(!n.parentNode.closest('pre,a'))nodes.push(n);}
      nodes.forEach(function(node){
        var t=node.nodeValue;rideLoc.lastIndex=0;if(!rideLoc.test(t))return;rideLoc.lastIndex=0;
        var frag=document.createDocumentFragment(),last=0,m;
        while((m=rideLoc.exec(t))){
          var start=m.index+m[1].length;
          frag.appendChild(document.createTextNode(t.slice(last,start)));
          var a=document.createElement('a');a.className='loc';a.href='ride-open:'+m[2]+':'+m[3];a.textContent=m[2]+':'+m[3];
          frag.appendChild(a);last=start+m[2].length+1+m[3].length;
        }
        frag.appendChild(document.createTextNode(t.slice(last)));node.parentNode.replaceChild(frag,node);
      });
    }
    function rideTools(root){
      root.querySelectorAll('pre').forEach(function(pre){
        if(pre.querySelector('.tools'))return;
        var bar=document.createElement('div');bar.className='tools';
        [['Copy','copy'],['Insert','insert']].forEach(function(b){
          var btn=document.createElement('button');btn.textContent=b[0];
          btn.addEventListener('click',function(e){e.preventDefault();var code=pre.querySelector('code')||pre;
            window.webkit.messageHandlers.rideChat.postMessage({action:b[1],text:code.innerText});});
          bar.appendChild(btn);
        });
        pre.appendChild(bar);
      });
    }
    function rideNearBottom(){return window.innerHeight+window.scrollY>=document.body.scrollHeight-40;}
    function rideUpsert(id,html,follow){
      var main=document.getElementById('main');var el=document.getElementById('m-'+id);
      var stick=follow||rideNearBottom();
      if(!el){el=document.createElement('div');el.id='m-'+id;main.appendChild(el);}
      el.innerHTML=html;rideLinkify(el);rideTools(el);
      if(stick)window.scrollTo(0,document.body.scrollHeight);
    }
    function rideClear(html){document.getElementById('main').innerHTML=html||'';}
    document.addEventListener('click',function(e){
      var a=e.target.closest('a');if(!a)return;var href=a.getAttribute('href')||'';
      if(href.indexOf('ride-open:')===0){e.preventDefault();e.stopPropagation();
        window.webkit.messageHandlers.rideChat.postMessage({action:'open',text:href.slice(10)});}
    },true);
    """
}
