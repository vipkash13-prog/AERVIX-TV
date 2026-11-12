package com.omeda.arc;

/** Geometry only: retain all nontransparent artwork and fit it without stretching. */
final class IconArtwork {
    private IconArtwork() { }

    static int[] alphaBounds(int[] pixels, int width, int height) {
        int left = width, top = height, right = 0, bottom = 0;
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                if ((pixels[y * width + x] >>> 24) != 0) {
                    left = Math.min(left, x);
                    top = Math.min(top, y);
                    right = Math.max(right, x + 1);
                    bottom = Math.max(bottom, y + 1);
                }
            }
        }
        return right > left && bottom > top ? new int[]{left, top, right, bottom} : null;
    }

    static int background(int[] pixels, int width, int[] bounds) {
        final int fallback = 0xFF0B1018;
        int inset = Math.min(3, Math.min((bounds[2]-bounds[0])/4, (bounds[3]-bounds[1])/4));
        int left = bounds[0]+inset, right = bounds[2]-1-inset;
        int top = bounds[1]+inset, bottom = bounds[3]-1-inset;
        int[] samples = {pixels[top*width+left],pixels[top*width+right],pixels[bottom*width+left],pixels[bottom*width+right]};
        int first = samples[0];
        for (int sample : samples) {
            if ((sample >>> 24) < 250) return fallback;
            int distance = Math.abs(((sample>>16)&255)-((first>>16)&255))
                    + Math.abs(((sample>>8)&255)-((first>>8)&255)) + Math.abs((sample&255)-(first&255));
            if (distance > 36) return fallback;
        }
        return 0xFF000000 | (first & 0xFFFFFF);
    }

    static float[] fit(int width, int height, int targetWidth, int targetHeight, int padding) {
        float factor = Math.min((float) (targetWidth - 2 * padding) / width,
                (float) (targetHeight - 2 * padding) / height);
        float drawWidth = width * factor, drawHeight = height * factor;
        return new float[]{(targetWidth - drawWidth) / 2f, (targetHeight - drawHeight) / 2f,
                (targetWidth + drawWidth) / 2f, (targetHeight + drawHeight) / 2f};
    }
}
