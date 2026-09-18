// Tripo CLI 0.4.0: use its authenticated client and task runner for texture v3.5.
// Run from the repository root. This submits one paid texture task, not geometry.
import { newClient } from 'file:///D:/Software/nodejs/node_modules/tripo-cli/dist/commands/shared.js';
import { resolveInputValue, runTask } from 'file:///D:/Software/nodejs/node_modules/tripo-cli/dist/core/task-service.js';
import { installProxyFromEnv } from 'file:///D:/Software/nodejs/node_modules/tripo-cli/dist/core/proxy.js';
import { mkdir, writeFile } from 'node:fs/promises';
await installProxyFromEnv();
const directory = 'ArtSource/Characters/Farmer/texture-v3-20260918';
const client = newClient();
const mesh = await resolveInputValue(client, 'ArtSource/Characters/Farmer/tpose-v2-20260918/farmer_gongbi.glb');
const style = await resolveInputValue(client, 'ArtSource/Characters/Farmer/tpose-v2-20260918/front.png');
const settings = {
  model: 'v3.5-20260815', texture_quality: 'detailed', delight: false,
  pbr: false, bake: false, texture_alignment: 'geometry', texture_seed: 202609185,
  texture_prompt: {
    text: 'Chinese Ming commoner farmer painted in classical GONGBI DANCAI technique, match the reference precisely. Fine controlled dark umber ink lines trace actual collar edges, sleeve hems, sash seams, fingers, facial features and selected flowing garment folds. Clearly visible delicate brush contours, not thick cartoon outlines. Broad clean pale sage-green mineral pigment washes on shirt, pale warm ochre skin, restrained rose cheeks, muted tea-brown trousers, ivory collar and cuffs. Elegant layered translucent color gradients, selective darker ink pooling along actual folds. Hair drawn as grouped fine ink strands, friendly eyes softly painted without glossy highlights. Remove realistic woven fabric grain, mottled noise, uniform fuzzy cloth shading, plastic skin, leather texture and baked directional shadows. Plain clothing with NO embroidery, floral patterns, symbols or lettering. Preserve exact facial identity, level eyes, upright head, existing colors and garment construction. Delicate traditional album painting, matte and softly shaded, not photorealistic, not shiny 3D toy.',
    style_image: {file_token: style.value}
  }
};
await mkdir(directory, {recursive:true});
await writeFile(directory + '/request.json', JSON.stringify({...settings, texture_prompt:{...settings.texture_prompt, style_image:{path:'../tpose-v2-20260918/front.png'}}, input:'ArtSource/Characters/Farmer/tpose-v2-20260918/farmer_gongbi.glb'},null,2));
const result = await runTask({client,request:{endpoint:'/v3/models/texture',payload:{input:mesh.value,...settings}},taskType:'texture',name:'farmer-gongbi-texture-v3',outDir:'.local/farmer-gongbi-texture-v3'});
await writeFile('.local/farmer-gongbi-texture-v3/result.json', JSON.stringify(result,null,2));
console.log(JSON.stringify({task_id:result.task_id,status:result.status,credits:result.credits_consumed,output_dir:result.output_dir}));
