package com.tfue.onepiece.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.util.ARGB;
import net.minecraft.world.phys.Vec3;
import org.joml.Vector3f;

/** Small geometry toolkit for the hand-built effects. */
public final class Geo {
	public static final int FULL_BRIGHT = 0xF000F0;

	private Geo() {
	}

	public static void v(VertexConsumer b, PoseStack.Pose pose, float x, float y, float z, float u, float v, int color, int light) {
		b.addVertex(pose, x, y, z).setColor(color).setUv(u, v).setOverlay(OverlayTexture.NO_OVERLAY).setLight(light).setNormal(pose, 0.0F, 1.0F, 0.0F);
	}

	public static void v(VertexConsumer b, PoseStack.Pose pose, Vector3f p, float u, float v, int color, int light) {
		v(b, pose, p.x, p.y, p.z, u, v, color, light);
	}

	public static int alpha(int color, float alpha) {
		int a = (int) (ARGB.alpha(color) * Math.max(0.0F, Math.min(1.0F, alpha)));
		return ARGB.color(a, ARGB.red(color), ARGB.green(color), ARGB.blue(color));
	}

	public static float luminance(int color) {
		return (ARGB.red(color) * 0.299F + ARGB.green(color) * 0.587F + ARGB.blue(color) * 0.114F) / 255.0F;
	}

	/** Camera-facing square of half-size {@code s}; the pose must already be rotated to face the camera. */
	public static void billboard(VertexConsumer b, PoseStack.Pose pose, float cx, float cy, float s, float u0, float v0, float u1, float v1, int color, int light) {
		v(b, pose, cx - s, cy - s, 0, u0, v1, color, light);
		v(b, pose, cx + s, cy - s, 0, u1, v1, color, light);
		v(b, pose, cx + s, cy + s, 0, u1, v0, color, light);
		v(b, pose, cx - s, cy + s, 0, u0, v0, color, light);
	}

	/**
	 * A box stretched from {@code a} to {@code b} with square cross-section {@code w}. The texture repeats
	 * along the length every {@code tile} blocks. Used for rubber arms and legs.
	 */
	public static void tube(VertexConsumer buf, PoseStack.Pose pose, Vec3 a, Vec3 b, float w, float tile, int color, int light) {
		Vec3 dir = b.subtract(a);
		double len = dir.length();
		if (len < 1.0E-4) {
			return;
		}
		Vec3 f = dir.scale(1.0 / len);
		Vec3 up = Math.abs(f.y) > 0.95 ? new Vec3(1, 0, 0) : new Vec3(0, 1, 0);
		Vec3 s = f.cross(up).normalize().scale(w * 0.5);
		Vec3 u = s.cross(f).normalize().scale(w * 0.5);
		float vLen = (float) (len / tile);
		Vec3[] corners = {s.add(u), s.subtract(u), s.scale(-1).subtract(u), s.scale(-1).add(u)};
		for (int n = 0; n < 4; n++) {
			Vec3 c0 = corners[n];
			Vec3 c1 = corners[(n + 1) % 4];
			quad(buf, pose, a.add(c0), a.add(c1), b.add(c1), b.add(c0), 0.0F, 0.0F, 1.0F, vLen, color, light, a.add(b).scale(0.5));
		}
	}

	/** Axis-aligned box around the origin of the current pose, with one texture on every face. */
	public static void cube(VertexConsumer buf, PoseStack.Pose pose, float hx, float hy, float hz, int color, int light) {
		Vec3[] p = {
			new Vec3(-hx, -hy, -hz), new Vec3(hx, -hy, -hz), new Vec3(hx, hy, -hz), new Vec3(-hx, hy, -hz),
			new Vec3(-hx, -hy, hz), new Vec3(hx, -hy, hz), new Vec3(hx, hy, hz), new Vec3(-hx, hy, hz)
		};
		int[][] faces = {{0, 1, 2, 3}, {5, 4, 7, 6}, {4, 0, 3, 7}, {1, 5, 6, 2}, {3, 2, 6, 7}, {4, 5, 1, 0}};
		for (int[] face : faces) {
			quad(buf, pose, p[face[0]], p[face[1]], p[face[2]], p[face[3]], 0, 1, 1, 0, color, light, Vec3.ZERO);
		}
	}

	/** Vertex with an explicit normal, so lit render types shade each face by its direction. */
	public static void vn(VertexConsumer b, PoseStack.Pose pose, Vec3 p, float u, float v, int color, int light, Vec3 n) {
		b.addVertex(pose, (float) p.x, (float) p.y, (float) p.z).setColor(color).setUv(u, v).setOverlay(OverlayTexture.NO_OVERLAY).setLight(light)
			.setNormal(pose, (float) n.x, (float) n.y, (float) n.z);
	}

	public static void quad(VertexConsumer b, PoseStack.Pose pose, Vec3 p0, Vec3 p1, Vec3 p2, Vec3 p3, float u0, float v0, float u1, float v1, int color, int light) {
		quad(b, pose, p0, p1, p2, p3, u0, v0, u1, v1, color, light, null);
	}

	/** Quad whose normal points away from {@code center} (when given) so solids light correctly. */
	public static void quad(VertexConsumer b, PoseStack.Pose pose, Vec3 p0, Vec3 p1, Vec3 p2, Vec3 p3, float u0, float v0, float u1, float v1, int color, int light,
		Vec3 center) {
		Vec3 n = p1.subtract(p0).cross(p3.subtract(p0));
		n = n.lengthSqr() > 1.0E-12 ? n.normalize() : new Vec3(0, 1, 0);
		if (center != null && n.dot(p0.add(p2).scale(0.5).subtract(center)) < 0) {
			n = n.scale(-1);
		}
		vn(b, pose, p0, u0, v0, color, light, n);
		vn(b, pose, p1, u1, v0, color, light, n);
		vn(b, pose, p2, u1, v1, color, light, n);
		vn(b, pose, p3, u0, v1, color, light, n);
	}

	/** A clenched fist centred on the origin, knuckles facing +Z, {@code s} is half its width. */
	public static void fist(VertexConsumer buf, PoseStack.Pose pose, float s, int color, int light) {
		box(buf, pose, -s, -s * 0.8F, -s * 0.9F, s, s * 0.75F, s * 0.45F, color, light);
		for (int n = 0; n < 4; n++) {
			float x0 = -s + n * s * 0.5F;
			float bump = n == 1 || n == 2 ? s * 0.08F : 0.0F;
			box(buf, pose, x0 + s * 0.03F, -s * 0.72F, s * 0.4F, x0 + s * 0.47F, s * 0.62F, s * 0.95F + bump, color, light);
			box(buf, pose, x0 + s * 0.06F, -s * 0.85F, s * 0.05F, x0 + s * 0.44F, -s * 0.5F, s * 0.7F, color, light);
		}
		box(buf, pose, -s * 1.22F, -s * 0.7F, -s * 0.2F, -s * 0.85F, s * 0.1F, s * 0.75F, color, light);
	}

	/** A camera-facing ribbon between two points (lightning, streaks). */
	public static void beam(VertexConsumer b, PoseStack.Pose pose, Vec3 a, Vec3 c, Vec3 camRel, float w, int colorA, int colorB, int light) {
		Vec3 dir = c.subtract(a);
		Vec3 toCam = camRel.subtract(a.add(c).scale(0.5));
		Vec3 side = dir.cross(toCam);
		if (side.lengthSqr() < 1.0E-8) {
			return;
		}
		side = side.normalize().scale(w * 0.5);
		v(b, pose, (float) (a.x - side.x), (float) (a.y - side.y), (float) (a.z - side.z), 0, 0, colorA, light);
		v(b, pose, (float) (a.x + side.x), (float) (a.y + side.y), (float) (a.z + side.z), 0, 1, colorA, light);
		v(b, pose, (float) (c.x + side.x), (float) (c.y + side.y), (float) (c.z + side.z), 1, 1, colorB, light);
		v(b, pose, (float) (c.x - side.x), (float) (c.y - side.y), (float) (c.z - side.z), 1, 0, colorB, light);
	}

	/** Box between two corners in the current pose. */
	public static void box(VertexConsumer buf, PoseStack.Pose pose, float x0, float y0, float z0, float x1, float y1, float z1, int color, int light) {
		Vec3[] p = {
			new Vec3(x0, y0, z0), new Vec3(x1, y0, z0), new Vec3(x1, y1, z0), new Vec3(x0, y1, z0),
			new Vec3(x0, y0, z1), new Vec3(x1, y0, z1), new Vec3(x1, y1, z1), new Vec3(x0, y1, z1)
		};
		int[][] faces = {{0, 1, 2, 3}, {5, 4, 7, 6}, {4, 0, 3, 7}, {1, 5, 6, 2}, {3, 2, 6, 7}, {4, 5, 1, 0}};
		Vec3 center = new Vec3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5);
		for (int[] face : faces) {
			quad(buf, pose, p[face[0]], p[face[1]], p[face[2]], p[face[3]], 0, 0, 1, 1, color, light, center);
		}
	}

	/** Open cylinder wall around the Y axis from y0 to y1. */
	public static void cylinder(VertexConsumer buf, PoseStack.Pose pose, float r0, float r1, float y0, float y1, int segments, float uTiles, int color, int light) {
		for (int n = 0; n < segments; n++) {
			float a0 = n / (float) segments * (float) (Math.PI * 2);
			float a1 = (n + 1) / (float) segments * (float) (Math.PI * 2);
			float u0 = n / (float) segments * uTiles;
			float u1 = (n + 1) / (float) segments * uTiles;
			v(buf, pose, (float) Math.cos(a0) * r0, y0, (float) Math.sin(a0) * r0, u0, 0, color, light);
			v(buf, pose, (float) Math.cos(a1) * r0, y0, (float) Math.sin(a1) * r0, u1, 0, color, light);
			v(buf, pose, (float) Math.cos(a1) * r1, y1, (float) Math.sin(a1) * r1, u1, 1, color, light);
			v(buf, pose, (float) Math.cos(a0) * r1, y1, (float) Math.sin(a0) * r1, u0, 1, color, light);
		}
	}

	/** Flat ring (or disc when inner is 0) around the Y axis; the outer edge can droop by {@code droop}. */
	public static void annulus(VertexConsumer buf, PoseStack.Pose pose, float inner, float outer, float y, float droop, int segments, int color, int light) {
		for (int n = 0; n < segments; n++) {
			float a0 = n / (float) segments * (float) (Math.PI * 2);
			float a1 = (n + 1) / (float) segments * (float) (Math.PI * 2);
			float c0 = (float) Math.cos(a0);
			float s0 = (float) Math.sin(a0);
			float c1 = (float) Math.cos(a1);
			float s1 = (float) Math.sin(a1);
			v(buf, pose, c0 * inner, y, s0 * inner, c0 * inner / outer * 0.5F + 0.5F, s0 * inner / outer * 0.5F + 0.5F, color, light);
			v(buf, pose, c1 * inner, y, s1 * inner, c1 * inner / outer * 0.5F + 0.5F, s1 * inner / outer * 0.5F + 0.5F, color, light);
			v(buf, pose, c1 * outer, y + droop, s1 * outer, c1 * 0.5F + 0.5F, s1 * 0.5F + 0.5F, color, light);
			v(buf, pose, c0 * outer, y + droop, s0 * outer, c0 * 0.5F + 0.5F, s0 * 0.5F + 0.5F, color, light);
		}
	}

	/** Two crossed vertical planes, good for flames and hair that should look full from any angle. */
	public static void crossed(VertexConsumer buf, PoseStack.Pose pose, float w, float h, float u0, float u1, int color, int light) {
		v(buf, pose, -w, 0, 0, u0, 1, color, light);
		v(buf, pose, w, 0, 0, u1, 1, color, light);
		v(buf, pose, w, -h, 0, u1, 0, color, light);
		v(buf, pose, -w, -h, 0, u0, 0, color, light);
		v(buf, pose, 0, 0, -w, u0, 1, color, light);
		v(buf, pose, 0, 0, w, u1, 1, color, light);
		v(buf, pose, 0, -h, w, u1, 0, color, light);
		v(buf, pose, 0, -h, -w, u0, 0, color, light);
	}
}
