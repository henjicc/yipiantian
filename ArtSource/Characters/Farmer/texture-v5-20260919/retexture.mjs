// Tripo CLI 0.4.0: use its authenticated client and task runner for texture v3.5.
// Run from the repository root. This submits one paid texture task, not geometry.
import { newClient } from 'file:///D:/Software/nodejs/node_modules/tripo-cli/dist/commands/shared.js';
import { resolveInputValue, runTask } from 'file:///D:/Software/nodejs/node_modules/tripo-cli/dist/core/task-service.js';
import { installProxyFromEnv } from 'file:///D:/Software/nodejs/node_modules/tripo-cli/dist/core/proxy.js';
import { mkdir, writeFile } from 'node:fs/promises';
await installProxyFromEnv();
const directory = 'ArtSource/Characters/Farmer/texture-v5-20260919';
const client = newClient();
const mesh = await resolveInputValue(client, 'ArtSource/Characters/Farmer/tpose-v2-20260918/farmer_gongbi.glb');
const style = await resolveInputValue(client, 'ArtSource/Characters/Farmer/texture-v5-20260919/reference.png');
const settings = {
  model: 'v3.5-20260815', texture_quality: 'detailed', delight: false,
  pbr: false, bake: false, texture_alignment: 'geometry', texture_seed: 202609190,
  texture_prompt: {image: {file_token: style.value}}
};
await mkdir(directory, {recursive:true});
await writeFile(directory + '/request.json', JSON.stringify({...settings, texture_prompt:{image:{path:'reference.png'}}, input:'ArtSource/Characters/Farmer/tpose-v2-20260918/farmer_gongbi.glb'},null,2));
const result = await runTask({client,request:{endpoint:'/v3/models/texture',payload:{input:mesh.value,...settings}},taskType:'texture',name:'farmer-gongbi-texture-v5',outDir:'.local/farmer-gongbi-texture-v5'});
await writeFile('.local/farmer-gongbi-texture-v5/result.json', JSON.stringify(result,null,2));
console.log(JSON.stringify({task_id:result.task_id,status:result.status,credits:result.credits_consumed,output_dir:result.output_dir}));
