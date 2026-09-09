"""Run with Blender --background --factory-startup --python build.py.

Original editable geometry based on the repository's concept art. No downloads.
One Blender unit = one tile before the sprite camera's Y projection correction.
"""
from pathlib import Path
import math
import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
OUTPUT = ROOT / 'graphics/entity/train-container/train-loading'
OUTPUT.mkdir(parents=True, exist_ok=True)
PPU = 64


def material(name, color, metal=0.0, roughness=0.6):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = nodes.get('Principled BSDF')
    coords = nodes.new('ShaderNodeTexCoord')
    coords.label = 'Object-space wear shared by both orientations'

    def noise(label, scale, stretch=(1, 1, 1)):
        mapping = nodes.new('ShaderNodeVectorMath')
        mapping.operation = 'MULTIPLY'
        mapping.inputs[1].default_value = stretch
        links.new(coords.outputs['Object'], mapping.inputs[0])
        tex = nodes.new('ShaderNodeTexNoise')
        tex.label = label
        tex.inputs['Scale'].default_value = scale
        tex.inputs['Detail'].default_value = 3
        links.new(mapping.outputs[0], tex.inputs['Vector'])
        return tex.outputs['Fac']

    def ramp(label, source, stops):
        node = nodes.new('ShaderNodeValToRGB')
        node.label = label
        for i, (position, rgba) in enumerate(stops):
            element = node.color_ramp.elements[i] if i < 2 else node.color_ramp.elements.new(position)
            element.position, element.color = position, rgba
        links.new(source, node.inputs[0])
        return node.outputs[0]

    grime = noise('Oil stains and oxidation patches', 5.5, (1, 1.7, .65))
    scratches = noise('Directional rubbed metal', 1, (100, 5, 35))
    grain = noise('Fine pitted surface', 95)
    base = ramp('Steel / warm accumulated grime', grime, [
        (.25, (.021, .016, .010, 1)),
        (.40, (*(c * .25 for c in color), 1)),
        (.51, (*(c * .70 for c in color), 1)),
        (.62, (*(min(c * 1.4, 1) for c in color), 1)),
        (.78, (.16, .082, .027, 1)),
    ])
    rubbed = ramp('Scratches readable at sprite scale', scratches, [
        (.30, (.30, .27, .23, 1)), (.67, (1, 1, 1, 1))])
    multiply = nodes.new('ShaderNodeMixRGB')
    multiply.blend_type = 'MULTIPLY'
    multiply.inputs[0].default_value = .45
    links.new(base, multiply.inputs[1])
    links.new(rubbed, multiply.inputs[2])
    ao = nodes.new('ShaderNodeAmbientOcclusion')
    ao.label = 'Dirt in panel joints and roller sockets'
    ao.inputs['Distance'].default_value = .16
    ao.samples = 16
    links.new(multiply.outputs[0], ao.inputs['Color'])
    links.new(ao.outputs['Color'], shader.inputs['Base Color'])
    links.new(ramp('Uneven polish versus oily roughness', grime, [
        (.30, (.85, .85, .85, 1)),
        (.62, (roughness, roughness, roughness, 1))]), shader.inputs['Roughness'])
    links.new(ramp('Oxide versus exposed steel', grime, [
        (.30, (.15, .15, .15, 1)),
        (.55, (metal, metal, metal, 1))]), shader.inputs['Metallic'])
    bump = nodes.new('ShaderNodeBump')
    bump.label = 'Subtle pits, not large dents'
    bump.inputs['Strength'].default_value = .24
    bump.inputs['Distance'].default_value = .008
    links.new(grain, bump.inputs['Height'])
    links.new(bump.outputs['Normal'], shader.inputs['Normal'])
    return mat


def box(name, loc, size, mat, bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new('Machined edge', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    active_module.objects.link(obj)
    return obj


def cylinder(name, loc, radius, length, mat, axis='Z'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=length, location=loc)
    obj = bpy.context.object
    obj.name = name
    if axis == 'Y':
        obj.rotation_euler.x = math.pi / 2
    obj.data.materials.append(mat)
    mod = obj.modifiers.new('Rim bevel', 'BEVEL')
    mod.width, mod.segments = 0.008, 2
    obj.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    active_module.objects.link(obj)
    return obj


def warnings(prefix, center, length):
    x, y, z = center
    box(prefix + ' warning backing', center, (length, .025, .085), yellow, .006)
    for i in range(int(length / .15)):
        stripe = box(prefix + ' diagonal black',
                     (x - length / 2 + .08 + i * .15, y - math.copysign(.016, -y), z),
                     (.065, .014, .088), dark, .002)
        stripe.rotation_euler.y = -.5


bpy.ops.wm.read_factory_settings(use_empty=True)
catalog = bpy.context.scene
catalog.name = 'MODEL - editable module catalog'
steel = material('Weathered graphite steel', (.26, .235, .205), .88, .30)
lid = material('Galvanized ribbed lid', (.56, .55, .53), .92, .27)
dark = material('Recess and rubber', (.025, .033, .037), .15)
roller = material('Roller machined metal', (.48, .49, .48), .95, .22)
yellow = material('Faded safety ochre', (.64, .39, .065), .25)
rust = material('Oxidized fastener', (.22, .13, .065), .4)
green = material('Status lens - static', (.07, .44, .32), .3)

modules = {}
for name in ('T6', 'J', 'L', 'R'):
    modules[name] = bpy.data.collections.new(name + ' - source geometry')
    catalog.collection.children.link(modules[name])

active_module = modules['T6']
box('T6 enclosed container core', (0, 0, .29), (6, .70, .48), steel)
box('T6 dark continuous plinth', (0, 0, .08), (6, .86, .13), dark)
box('T6 flat sealed lid', (0, 0, .63), (6, .60, .10), lid, .018)
for i in range(48):
    box('T6 lid rib %02d' % i, (-2.9375 + i * .125, 0, .689), (.029, .57, .02), steel, .005)
for side in (-1, 1):
    y = side * .425
    box('T6 upper side rail', (0, y, .59), (6, .07, .10), steel, .012)
    box('T6 lower side rail', (0, y, .19), (6, .07, .12), steel, .012)
    for bay in range(3):
        x = -2 + bay * 2
        box('T6 transfer bay %d recess' % bay, (x, side * .375, .405), (1.78, .05, .28), dark, .012)
        warnings('T6 bay %d' % bay, (x, side * .469, .20), 1.65)
        for i in range(9):
            rx = x - .73 + i * .1825
            cylinder('T6 bay %d roller %02d' % (bay, i), (rx, side * .41, .40), .066, .15, roller, 'Y')
            cylinder('T6 roller hub', (rx, side * .49, .40), .028, .013, dark, 'Y')
    for x in (-2.96, -1, 1, 2.96):
        box('T6 reinforced upright', (x, side * .439, .36), (.095, .10, .53), steel, .015)
        for z in (.15, .55):
            cylinder('T6 rivet', (x, side * .498, z), .020, .012, rust, 'Y')

active_module = modules['J']
box('J connection housing', (0, 0, .32), (1, .78, .55), steel)
box('J gasket plinth', (0, 0, .08), (1, .86, .13), dark)
box('J control tower', (0, 0, .49), (.42, .91, .81), steel)
box('J top maintenance lid', (0, 0, .91), (.34, .80, .04), lid)
for side in (-1, 1):
    box('J recessed control panel', (0, side * .466, .53), (.27, .035, .29), dark, .008)
    box('J display', (0, side * .487, .59), (.16, .01, .06), green, .003)
    warnings('J', (0, side * .474, .30), .38)
    for x in (-.42, .42):
        box('J reinforcement strap', (x, side * .42, .40), (.09, .08, .60), steel)
        box('J warning tab', (x, side * .40, .72), (.085, .14, .04), yellow, .006)
cylinder('J amber status beacon base', (0, .12, .95), .075, .035, dark)
cylinder('J amber status beacon', (0, .12, 1.0), .049, .09, yellow)

for name, sign in (('L', -1), ('R', 1)):
    active_module = modules[name]
    box(name + ' end cover', (0, 0, .43), (.20, .93, .78), steel)
    box(name + ' top cap', (0, 0, .84), (.22, .89, .055), lid, .012)
    box(name + ' end inset', (sign * .105, 0, .46), (.025, .66, .47), dark, .008)
    for y in (-.40, .40):
        box(name + ' corner bumper', (0, y, .42), (.23, .12, .78), steel, .012)
        box(name + ' ochre top marker', (0, y, .88), (.12, .12, .035), yellow, .006)
        for z in (.18, .70):
            cylinder(name + ' cover bolt', (0, y * 1.2, z), .025, .016, roller, 'Y')


def setup_scene(name, width, height):
    scene = bpy.data.scenes.new(name)
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 96
    scene.cycles.use_denoising = False
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.world = bpy.data.worlds.new(name + ' ambient')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.58, .59, .62, 1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = .32
    scene.view_settings.view_transform = 'Standard'
    cam = bpy.data.objects.new(name + ' orthographic camera', bpy.data.cameras.new(name + ' camera'))
    scene.collection.objects.link(cam)
    cam.location = (0, -20, 20)
    cam.rotation_euler = (Vector((0, 0, 0)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = max(width, height) / PPU
    scene.camera = cam
    sun = bpy.data.objects.new(name + ' northwest sun', bpy.data.lights.new(name + ' sun', 'SUN'))
    scene.collection.objects.link(sun)
    sun.rotation_euler = Vector((.65, .45, -1)).to_track_quat('-Z', 'Y').to_euler()
    sun.data.energy = 2.0
    sun.data.angle = .09
    # Reflected strip highlights the metal; reduced ambient keeps sockets dark.
    softbox = bpy.data.objects.new(name + ' metal reflection strip', bpy.data.lights.new(name + ' strip', 'AREA'))
    scene.collection.objects.link(softbox)
    softbox.location = (-3, -4, 6)
    softbox.rotation_euler = (-softbox.location).to_track_quat('-Z', 'Y').to_euler()
    softbox.data.energy = 650
    softbox.data.shape = 'RECTANGLE'
    softbox.data.size = 7
    softbox.data.size_y = 2
    return scene


def copy_module(scene, module, transform):
    result = []
    collection = bpy.data.collections.new(scene.name + ' ' + module)
    scene.collection.children.link(collection)
    for source in modules[module].objects:
        obj = source.copy()
        collection.objects.link(obj)
        obj.matrix_world = transform @ source.matrix_world
        result.append(obj)
    return result


# The game uses square tiles in screen coordinates. Compensate the 45-degree
# camera foreshortening after orientation, so both axes advance exactly 64 px.
projection = Matrix.Diagonal((1, math.sqrt(2), 1, 1))
render_jobs = []
for orientation, angle in (('wide', 0), ('high', -math.pi / 2)):
    for module, long_pixels in (('T6', 512), ('J', 192), ('L', 160), ('R', 160)):
        dims = (long_pixels, 192) if orientation == 'wide' else (192, long_pixels)
        name = orientation + '-' + module.lower()
        scene = setup_scene(name, *dims)
        objects = copy_module(scene, module, projection @ Matrix.Rotation(angle, 4, 'Z'))
        scene.render.filepath = str(OUTPUT / (name + '.png'))
        render_jobs.append(scene)
        # Project the actual evaluated mesh onto the ground along the sun ray.
        # A separate opaque silhouette is used; opacity is applied once by the
        # Lua tint, preventing dark self-overlap within a module.
        shadow_scene = setup_scene(name + '-shadow', *dims)
        black = bpy.data.materials.get('Shadow silhouette')
        if black is None:
            black = bpy.data.materials.new('Shadow silhouette')
            black.use_nodes = True
            nodes = black.node_tree.nodes
            nodes.clear()
            output = nodes.new('ShaderNodeOutputMaterial')
            emission = nodes.new('ShaderNodeEmission')
            emission.inputs[0].default_value = (0, 0, 0, 1)
            black.node_tree.links.new(emission.outputs[0], output.inputs[0])
        bpy.context.window.scene = scene
        depsgraph = bpy.context.evaluated_depsgraph_get()
        for obj in objects:
            evaluated = obj.evaluated_get(depsgraph)
            mesh = bpy.data.meshes.new_from_object(evaluated)
            for vertex in mesh.vertices:
                v = obj.matrix_world @ vertex.co
                vertex.co = (v.x + .65 * v.z, v.y + .45 * v.z, 0)
            mesh.materials.clear()
            mesh.materials.append(black)
            projected = bpy.data.objects.new(obj.name + ' ground shadow', mesh)
            shadow_scene.collection.objects.link(projected)
        shadow_scene.cycles.samples = 8
        shadow_scene.cycles.use_denoising = False
        shadow_scene.render.filepath = str(OUTPUT / (name + '-shadow.png'))
        render_jobs.append(shadow_scene)

# Catalog is an editable 13-tile assembly using collection instances. Source
# collections are kept in the file but unlinked here to avoid double geometry.
for collection in modules.values():
    catalog.collection.children.unlink(collection)
for module, x in (('T6', -3.5), ('J', 0), ('T6', 3.5), ('L', -6.38), ('R', 6.38)):
    obj = bpy.data.objects.new(module + ' assembly instance', None)
    obj.instance_type = 'COLLECTION'
    obj.instance_collection = modules[module]
    obj.location.x = x
    catalog.collection.objects.link(obj)

reference_path = ROOT / '列車隣接コンテナデザイン.png'
if reference_path.exists():
    reference = bpy.data.images.load(str(reference_path))
    reference.pack()

bpy.context.window.scene = bpy.data.scenes['wide-t6']
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / 'train-loading.blend'))
for scene in render_jobs:
    bpy.context.window.scene = scene
    print('RENDERING', scene.name, flush=True)
    bpy.ops.render.render(write_still=True)
print('All train-loading sprites rendered.', flush=True)
