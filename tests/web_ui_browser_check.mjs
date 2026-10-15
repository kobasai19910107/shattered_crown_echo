// P6 smoke verification: real Chromium browser, iPhone-like viewports.
// NOTE: this is NOT an actual iPhone Safari test.
import { chromium } from "playwright";
import fs from "node:fs/promises";
import path from "node:path";
const output = process.env.SCE_BROWSER_ARTIFACT_DIR || "browser-artifacts";
await fs.mkdir(output,{recursive:true});
const browser = await chromium.launch({headless:true,args:[
  "--enable-webgl",
  "--enable-unsafe-swiftshader",
  "--use-angle=swiftshader",
  "--disable-dev-shm-usage"
]});
const devices=[
  {label:"iphone-landscape-844x390",width:844,height:390,touch:true},
  {label:"iphone-landscape-932x430",width:932,height:430,touch:true},
  {label:"iphone-portrait-390x844",width:390,height:844,touch:true},
];
const summary=[];
let failures=0;
try {
  for(const device of devices) {
    const context=await browser.newContext({
      viewport:{width:device.width,height:device.height},
      deviceScaleFactor:2,
      isMobile:true,hasTouch:device.touch
    });
    const page=await context.newPage();
    const errors=[];
    page.on("pageerror", e=>errors.push("PAGE: "+String(e)));
    page.on("console", m=>{
      if(m.type()==="error")errors.push("CONSOLE: "+m.text());
    });
    page.on("response",res=>{
      if(res.status()>=400)errors.push("HTTP "+res.status()+" "+res.url());
    });
    let loadError="";
    try {
      await page.goto("http://127.0.0.1:8765/index.html",{waitUntil:"domcontentloaded",timeout:30000});
      await page.locator("canvas").first().waitFor({state:"visible",timeout:30000});
      await page.waitForTimeout(8500);
    }catch(e){loadError=String(e);}
    const result=await page.evaluate(()=>{
      const canvas=document.querySelector("canvas");
      const rect=canvas?.getBoundingClientRect();
      return {
        viewport:{width:innerWidth,height:innerHeight},
        canvasRect:rect?{x:rect.x,y:rect.y,width:rect.width,height:rect.height}:null,
        document:{scrollWidth:document.documentElement.scrollWidth,scrollHeight:document.documentElement.scrollHeight},
        canvasVisible:!!rect&&rect.width>0&&rect.height>0,
        devicePixelRatio:window.devicePixelRatio
      };
    });
    await page.screenshot({path:path.join(output,device.label+".png"),fullPage:false});
    if(device.width>device.height && !loadError) {
      // A disposable browser profile has no save, so the title page
      // offers "最初から". Tap its center and capture the actual Web hub.
      await page.touchscreen.tap(Math.round(device.width/2),Math.round(device.height*0.615));
      await page.waitForTimeout(1800);
      await page.screenshot({path:path.join(output,device.label+"-after-new-game.png"),fullPage:false});
    }
    const noOverflow=result.document.scrollWidth<=device.width+2&&result.document.scrollHeight<=device.height+2;
    const ok=!loadError&&result.canvasVisible&&noOverflow&&!errors.some(x=>x.startsWith("PAGE:")||x.startsWith("HTTP 404"));
    if(!ok)failures++;
    summary.push({device:device.label,pass:ok,loadError,errors,metrics:result});
    await context.close();
  }
}finally{await browser.close();}
await fs.writeFile(path.join(output,"browser-report.json"),JSON.stringify({summary,failures},null,2),"utf8");
for(const item of summary)console.log("P6_BROWSER "+item.device+" "+(item.pass?"PASS":"FAIL")+" "+JSON.stringify({errors:item.errors,metrics:item.metrics,loadError:item.loadError}));
if(failures>0)process.exit(1);
