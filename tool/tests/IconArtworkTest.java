package com.omeda.arc;

import java.util.Arrays;

public final class IconArtworkTest {
    public static void main(String[] args) {
        int[] pixels = new int[100 * 100];
        assert IconArtwork.alphaBounds(pixels, 100, 100) == null;
        for (int y = 30; y < 70; y++) for (int x = 10; x < 90; x++) pixels[y * 100 + x] = 0xFF112233;
        assert Arrays.equals(IconArtwork.alphaBounds(pixels, 100, 100), new int[]{10, 30, 90, 70});
        assert IconArtwork.background(pixels,100,new int[]{10,30,90,70}) == 0xFF112233;
        pixels[33*100+13] = 0xFFABCDEF;
        assert IconArtwork.background(pixels,100,new int[]{10,30,90,70}) == 0xFF0B1018;
        pixels[0] = 0x01000000; // Keep even faint shadows; do not trim visible pixels.
        assert Arrays.equals(IconArtwork.alphaBounds(pixels, 100, 100), new int[]{0, 0, 90, 70});
        for (int[] size : new int[][]{{80,40},{40,80},{100,100}}) {
            float[] fit = IconArtwork.fit(size[0], size[1], 512, 512, 12);
            assert fit[0] >= 12 && fit[1] >= 12 && fit[2] <= 500 && fit[3] <= 500;
            assert Math.abs((fit[2]-fit[0])/(fit[3]-fit[1])-(float)size[0]/size[1]) < .001;
            assert Math.abs(Math.max(fit[2]-fit[0],fit[3]-fit[1])-488)<.001;
        }
        float[] tile = IconArtwork.fit(488,488,512,288,8);
        assert Math.abs((tile[2]-tile[0])-(tile[3]-tile[1])) < .001;
        assert tile[1] == 8 && tile[3] == 280;
        System.out.println("Original icon alpha bounds, faint shadows, portrait/landscape/square aspect ratios and uniform visible size verified.");
    }
}
