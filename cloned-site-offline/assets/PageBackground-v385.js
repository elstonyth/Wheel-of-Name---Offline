import{j as e,aU as u}from"./index-v385.js";function c(a){const o=e(()=>a.value.pageGradient?`
        radial-gradient(
          at 0% 0%,
          ${u(t.value[0],.3)} 0px,
          rgb(0 0 0 / 0) 50%
        ),
        radial-gradient(
          at 98% 1%,
          ${u(t.value[1],.3)} 0px,
          rgb(0 0 0 / 0) 50%
        ),
        ${n.value}
      `:n.value),t=e(()=>{const r=a.value.getCoalescedColors();return l(r)?["#3369E8","#D50F25"]:r.length>a.value.entries.length?[r[0],r[Math.max(a.value.entries.length-1,0)]]:[r[0],r[r.length-1]]}),n=e(()=>a.value.pageBackgroundColor.toLowerCase()==="#ffffff"?"transparent":a.value.pageBackgroundColor);return{pageBackgroundStyle:e(()=>({background:o.value}))}}function l(a){return a.length===4&&a[0]==="#3369E8"&&a[1]==="#D50F25"&&a[2]==="#EEB211"&&a[3]==="#009925"}export{c as u};
