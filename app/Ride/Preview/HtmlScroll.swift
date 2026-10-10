import Foundation

enum HtmlScroll {
    static let channel = "htmlScroll"

    static let script = """
    (function(){
      function y(){return window.scrollY||document.documentElement.scrollTop||(document.body&&document.body.scrollTop)||0}
      function post(){
        var h=window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.\(channel);
        if(h)h.postMessage(y());
      }
      window.addEventListener("scroll",post,true);
      window.addEventListener("pagehide",post);
    })();
    """

    static func offset(from body: Any) -> Double? {
        if let number = body as? NSNumber {
            return number.doubleValue
        }
        if let number = body as? Double {
            return number
        }
        if let number = body as? Int {
            return Double(number)
        }
        return nil
    }

    static func restore(_ y: Double) -> String {
        let value = (y.isFinite && y > 0) ? y : 0
        return "var y=\(value);window.scrollTo({left:0,top:y,behavior:'auto'});document.documentElement.scrollTop=y;if(document.body)document.body.scrollTop=y;(window.scrollY||document.documentElement.scrollTop||(document.body&&document.body.scrollTop)||0)"
    }
}
