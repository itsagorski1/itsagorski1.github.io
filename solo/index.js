const notes=["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"],
scales={minor:[0,3,5,7,10],major:[0,2,4,7,9]},
tuning={E2:40,A2:45,D3:50,G3:55,B3:59,E4:64};

function noteToFret(m){let r=[];for(const s in tuning){const f=m-tuning[s];if(f>=0&&f<=24)r.push(`${s[0]}:${f}`)}return r.join(" ");}

function makeSolo(len=12){
const k=document.getElementById("key").value,
m=document.getElementById("mode").value,
root=notes.indexOf(k);
let o=[];
for(let i=0;i<len;i++){
const step=scales[m][Math.floor(Math.random()*scales[m].length)],
midi=60+root+step;
o.push(noteToFret(midi));
}
return o.join(" | ");
}

document.getElementById("gen").onclick=()=>document.getElementById("out").textContent=makeSolo();
