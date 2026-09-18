// Tripo CLI 0.4.0: use its authenticated client and task runner for texture v3.5.
// Run from the repository root. This submits one paid texture task, not geometry.
import { newClient } from 'file:///D:/Software/nodejs/node_modules/tripo-cli/dist/commands/shared.js';
import { resolveInputValue, runTask } from 'file:///D:/Software/nodejs/node_modules/tripo-cli/dist/core/task-service.js';
import { installProxyFromEnv } from 'file:///D:/Software/nodejs/node_modules/tripo-cli/dist/core/proxy.js';
import { mkdir, writeFile } from 'node:fs/promises';
await installProxyFromEnv();
const directory = 'ArtSource/Crops/Greens/pbr-study-20260918';
const client = newClient();
const mesh = await resolveInputValue(client, 'Game/art/crops/greens/greens_mature.glb');
const style = await resolveInputValue(client, 'ArtSource/Crops/Greens/p2-gongbi-20260918/reference.png');
const settings = {
  model: 'v3.5-20260815', texture_quality: 'detailed', delight: true,
  pbr: true, bake: false, texture_alignment: 'geometry', texture_seed: 202609183,
  texture_prompt: {
    text: 'Fresh living bok choy leaves, Chinese gongbi light-colour hand-painted game asset. Preserve muted jade green ink washes and ivory stalks from the reference. Delicate branching leaf veins and shallow soft wrinkles following the leaf growth direction, subtle natural leaf surface, gently varied satin-matte roughness. Very restrained normal relief. Nonmetallic. No rubber, plastic, leather, stone, coarse pores, cracks, dirt or exaggerated bumps. No painted specular highlights or directional shadows. Maintain broad clean colour washes and selective fine contours; not photorealistic.',
    style_image: {file_token: style.value}
  }
};
await mkdir(directory, {recursive:true});
await writeFile(directory + '/request.json', JSON.stringify({...settings, texture_prompt:{...settings.texture_prompt, style_image:{path:'../p2-gongbi-20260918/reference.png'}}, input:'Game/art/crops/greens/greens_mature.glb'},null,2));
const result = await runTask({client,request:{endpoint:'/v3/models/texture',payload:{input:mesh.value,...settings}},taskType:'texture',name:'greens-pbr-study',outDir:'.local/greens-pbr-study'});
await writeFile('.local/greens-pbr-study/result.json', JSON.stringify(result,null,2));
console.log(JSON.stringify({task_id:result.task_id,status:result.status,credits:result.credits_consumed,output_dir:result.output_dir}));
