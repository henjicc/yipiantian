// Paid texture-only operation; preserve the existing P2 geometry.
import { newClient } from 'file:///D:/Software/nodejs/node_modules/tripo-cli/dist/commands/shared.js';
import { resolveInputValue, runTask } from 'file:///D:/Software/nodejs/node_modules/tripo-cli/dist/core/task-service.js';
import { installProxyFromEnv } from 'file:///D:/Software/nodejs/node_modules/tripo-cli/dist/core/proxy.js';
import { mkdir, writeFile } from 'node:fs/promises';
await installProxyFromEnv();
const kind = process.argv[2];
if (!['hoe', 'chair'].includes(kind)) throw new Error('Expected hoe or chair');
const directory = `ArtSource/Characters/Farmer/props/${kind}/ink`;
const client = newClient();
const mesh = await resolveInputValue(client, `ArtSource/Characters/Farmer/props/${kind}/${kind}.glb`);
const style = await resolveInputValue(client, `ArtSource/Characters/Farmer/props/${kind}/reference-ink.png`);
const settings = {
  model:'v3.5-20260815', texture_quality:'detailed', delight:false, pbr:false,
  bake:false, texture_alignment:'geometry', texture_seed:kind === 'hoe' ? 202609193 : 202609194,
  texture_prompt:{image:{file_token:style.value}}
};
await mkdir(directory, {recursive:true});
await writeFile(directory+'/request.json', JSON.stringify({...settings,input:`../${kind}.glb`,texture_prompt:{image:{path:'../reference-ink.png'}}},null,2));
const result = await runTask({client,request:{endpoint:'/v3/models/texture',payload:{input:mesh.value,...settings}},taskType:'texture',name:`farmer-${kind}-ink`,outDir:`.local/farmer-${kind}-ink`});
await writeFile(`.local/farmer-${kind}-ink/result.json`,JSON.stringify(result,null,2));
console.log(JSON.stringify({task_id:result.task_id,status:result.status,credits:result.credits_consumed,output_dir:result.output_dir}));
