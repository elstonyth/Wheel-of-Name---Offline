import{aI as t,d1 as s,av as l,cR as r}from"./index-v385.js";function m(e,o){const i=t(o);i.includes("ChunkLoadError")?p(e):d(e,i)}function d(e,o){const i=`
    <div style="display: flex; flex-direction: row">
      <div style="font-size: 60px; color: #d50f25; padding: 0 10px">
        <i class="fas fa-exclamation-circle"></i>
      </div>
      <div style="padding: 10px">
        ${e("app.An error occurred",{link:'<a href="https://old.wheelofnames.com">old.wheelofnames.com</a>'})}
        <br><br>
        <i>${o}</i>
      </div>
    </div>
  `;s.create({title:"Oops!",message:i,html:!0,ok:{label:e("common.Close"),unelevated:"",color:"primary",noCaps:""}})}function v(e,o){const a=`
    <div style="display: flex; flex-direction: row; align-items: center">
      <div style="font-size: 60px; color: #d50f25; padding: 0 10px">
        <i class="fas fa-exclamation-circle"></i>
      </div>
      <div style="padding: 10px">
        ${t(o)}
      </div>
    </div>
  `;s.create({title:"Oops!",message:a,html:!0,ok:{label:e("common.Close"),unelevated:"",color:"primary",noCaps:""}})}function u(e,o,i=()=>{}){const a=`
    <div style="display: flex; flex-direction: row; align-items: center">
      <div style="font-size: 60px; color: #21BA45; padding: 0 10px">
        <i class="fas fa-circle-check"></i>
      </div>
      <div style="padding: 10px; font-size: 1.2em">
        ${o}
      </div>
    </div>
  `;s.create({message:a,html:!0,ok:{label:e("common.OK"),unelevated:"",color:"primary",noCaps:""}}).onOk(i)}function g(e,o){const i=`
    <div style="display: flex; flex-direction: row">
      <div style="font-size: 60px; color: #f2c037; padding: 0 10px">
        <i class="fas fa-question-circle"></i>
      </div>
      <div style="padding: 10px">
        ${o}
      </div>
    </div>
  `;return new Promise(a=>{s.create({title:e("app.Confirm"),message:i,html:!0,ok:{label:e("common.OK"),unelevated:"",color:"primary",noCaps:""},cancel:{label:e("common.Cancel"),flat:"",noCaps:""}}).onOk(()=>a(!0)).onCancel(()=>a(!1))})}function h(e,o,i){const a=`
    <div style="display: flex; flex-direction:row;">
      <div style="font-size:60px; color:#f2c037; padding: 0 10px">
        <i class="fas fa-question-circle"></i>
      </div>
      <div style="padding: 10px">
        ${o}
      </div>
    </div>
  `;s.create({title:e("app.Confirm"),message:a,html:!0,ok:{label:e("common.OK"),unelevated:"",color:"primary",noCaps:""},cancel:{label:e("common.Cancel"),flat:"",noCaps:""}}).onOk(()=>i())}function x(e,o,i){const a=`
    <div style="display: flex; flex-directvion:row;">
      <div style="font-size:60px; color:#3369e8; padding: 0 10px">
        <i class="fas fa-question-circle"></i>
      </div>
      <div style="padding: 10px">
        ${i}
      </div>
    </div>
  `;return new Promise(c=>{s.create({title:o,message:a,html:!0,ok:{label:e("optionsdialog.Yes"),unelevated:"",color:"primary",noCaps:""},cancel:{label:e("optionsdialog.No"),unelevated:"",color:"primary",noCaps:""}}).onOk(()=>c(!0)).onCancel(()=>c(!1))})}function p(e){const o=`
    <div style="display: flex; flex-direction: row">
      <div style="font-size: 60px; color: #3369e8; padding: 0 10px">
        <i class="fas fa-info-circle"></i>
      </div>
      <div style="padding: 10px">
        ${e("app.There is a new version")}
      </div>
    </div>
  `;s.create({title:e("app.New version available"),message:o,html:!0,ok:{label:e("common.Reload"),unelevated:"",color:"primary",noCaps:""},cancel:{label:e("common.Cancel"),flat:"",noCaps:""}}).onOk(()=>location.reload())}function y(e){l.create({message:e,position:n(),actions:[{icon:"fas fa-times",color:"white"}]})}function w(e,o,i){l.create({message:o,position:n(),timeout:7e3,actions:[{label:e("common.Undo"),color:"white",noCaps:!0,handler:i},{icon:"fas fa-times",color:"white"}]})}function C(e,o){l.create({message:e,position:n(),timeout:1e4,actions:[...o.map(i=>({label:i.label,color:"white",noCaps:!0,handler:i.callback})),{icon:"fas fa-times",color:"white"}]})}function b(e){l.create({message:t(e),position:n(),color:"negative",icon:"fas fa-exclamation-triangle"})}function n(){return r.is.mobile?"top":"bottom"}export{v as a,m as b,g as c,b as d,C as e,w as f,u as g,h,y as s,x as y};
