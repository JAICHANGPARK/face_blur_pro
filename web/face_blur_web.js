/**
 * Face Blur Web - ONNX Runtime + RFB-640 모델 기반 얼굴 감지
 * Rust 백엔드와 동일한 모델 및 로직 사용
 */

let session = null;
let priors = null;

const MODEL_INPUT_W = 640;
const MODEL_INPUT_H = 480;
const SCORE_THRESHOLD = 0.4;  // 0.6 → 0.3으로 낮춰서 더 많은 얼굴 감지
const IOU_THRESHOLD = 0.3;
const CENTER_VARIANCE = 0.1;
const SIZE_VARIANCE = 0.2;

/**
 * ONNX 모델 로드
 */
async function initFaceDetector() {
    if (session) return session;

    console.log('[FaceBlur] Loading ONNX model...');
    try {
        // Flutter 앱의 모델 경로
        const modelUrl = 'assets/assets/models/version-RFB-640.onnx';
        session = await ort.InferenceSession.create(modelUrl);
        priors = generatePriors640();
        console.log('[FaceBlur] ONNX model loaded. Priors:', priors.length);
        return session;
    } catch (error) {
        console.error('[FaceBlur] Model loading error:', error);
        throw error;
    }
}

/**
 * 앵커(Priors) 생성 - Rust 로직과 동일
 */
function generatePriors640() {
    const inputW = 640.0;
    const inputH = 480.0;

    // Feature Map 크기 (640x480 해상도)
    const featureMaps = [[80, 60], [40, 30], [20, 15], [10, 8]];
    const minSizes = [
        [10.0, 16.0, 24.0],
        [32.0, 48.0],
        [64.0, 96.0],
        [128.0, 192.0, 256.0]
    ];
    const steps = [8.0, 16.0, 32.0, 64.0];

    const priors = [];

    for (let k = 0; k < featureMaps.length; k++) {
        const mapSize = featureMaps[k];
        const minSize = minSizes[k];
        const step = steps[k];

        for (let i = 0; i < mapSize[1]; i++) {
            for (let j = 0; j < mapSize[0]; j++) {
                const cx = (j + 0.5) * step / inputW;
                const cy = (i + 0.5) * step / inputH;

                for (const size of minSize) {
                    priors.push({
                        cx: cx,
                        cy: cy,
                        w: size / inputW,
                        h: size / inputH
                    });
                }
            }
        }
    }

    return priors;
}

/**
 * Base64 이미지에서 얼굴 감지
 */
async function detectFacesWeb(base64ImageData) {
    try {
        console.log('[FaceBlur] detectFacesWeb called, base64 length:', base64ImageData.length);

        await initFaceDetector();

        // Base64를 Image로 변환
        const img = new Image();
        img.crossOrigin = 'anonymous';

        await new Promise((resolve, reject) => {
            img.onload = () => {
                console.log('[FaceBlur] Image loaded:', img.width, 'x', img.height);
                resolve();
            };
            img.onerror = (e) => {
                console.error('[FaceBlur] Image load error:', e);
                reject(e);
            };
            const prefix = base64ImageData.startsWith('/9j/') ? 'data:image/jpeg;base64,' : 'data:image/png;base64,';
            img.src = prefix + base64ImageData;
        });

        const origW = img.width;
        const origH = img.height;

        // Canvas에 640x480으로 리사이즈
        const canvas = document.createElement('canvas');
        canvas.width = MODEL_INPUT_W;
        canvas.height = MODEL_INPUT_H;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, MODEL_INPUT_W, MODEL_INPUT_H);

        // 이미지 데이터 추출
        const imageData = ctx.getImageData(0, 0, MODEL_INPUT_W, MODEL_INPUT_H);
        const pixels = imageData.data;

        // NCHW 형식으로 텐서 생성 (정규화: (val - 127) / 128)
        const tensorData = new Float32Array(1 * 3 * MODEL_INPUT_H * MODEL_INPUT_W);

        for (let y = 0; y < MODEL_INPUT_H; y++) {
            for (let x = 0; x < MODEL_INPUT_W; x++) {
                const pixelIdx = (y * MODEL_INPUT_W + x) * 4;
                const tensorIdx = y * MODEL_INPUT_W + x;

                // RGB 채널 (NCHW 형식)
                tensorData[0 * MODEL_INPUT_H * MODEL_INPUT_W + tensorIdx] = (pixels[pixelIdx + 0] - 127.0) / 128.0;     // R
                tensorData[1 * MODEL_INPUT_H * MODEL_INPUT_W + tensorIdx] = (pixels[pixelIdx + 1] - 127.0) / 128.0;     // G
                tensorData[2 * MODEL_INPUT_H * MODEL_INPUT_W + tensorIdx] = (pixels[pixelIdx + 2] - 127.0) / 128.0;     // B
            }
        }

        const inputTensor = new ort.Tensor('float32', tensorData, [1, 3, MODEL_INPUT_H, MODEL_INPUT_W]);

        console.log('[FaceBlur] Running ONNX inference...');
        const results = await session.run({ input: inputTensor });

        // 결과 추출 (confidences, boxes)
        const outputNames = Object.keys(results);
        console.log('[FaceBlur] Output names:', outputNames);

        const confidences = results[outputNames[0]].data;  // [1, N, 2]
        const boxes = results[outputNames[1]].data;        // [1, N, 4]

        // 얼굴 감지
        const detectedFaces = [];

        for (let i = 0; i < priors.length; i++) {
            const score = confidences[i * 2 + 1];  // 얼굴 클래스 점수

            if (score > SCORE_THRESHOLD) {
                const prior = priors[i];

                const locCx = boxes[i * 4 + 0];
                const locCy = boxes[i * 4 + 1];
                const locW = boxes[i * 4 + 2];
                const locH = boxes[i * 4 + 3];

                const cx = prior.cx + locCx * CENTER_VARIANCE * prior.w;
                const cy = prior.cy + locCy * CENTER_VARIANCE * prior.h;
                const w = prior.w * Math.exp(locW * SIZE_VARIANCE);
                const h = prior.h * Math.exp(locH * SIZE_VARIANCE);

                const x = (cx - w / 2.0) * origW;
                const y = (cy - h / 2.0) * origH;
                const realW = w * origW;
                const realH = h * origH;

                detectedFaces.push({
                    x1: x,
                    y1: y,
                    x2: x + realW,
                    y2: y + realH,
                    score: score
                });
            }
        }

        console.log('[FaceBlur] Before NMS:', detectedFaces.length, 'faces');

        // Non-Maximum Suppression
        const finalFaces = hardNms(detectedFaces, IOU_THRESHOLD);

        console.log('[FaceBlur] After NMS:', finalFaces.length, 'faces');

        // 결과 변환
        const results_array = finalFaces.map(f => ({
            x: Math.round(f.x1),
            y: Math.round(f.y1),
            width: Math.round(f.x2 - f.x1),
            height: Math.round(f.y2 - f.y1)
        }));

        console.log('[FaceBlur] Detected', results_array.length, 'faces');
        return JSON.stringify(results_array);

    } catch (error) {
        console.error('[FaceBlur] Face detection error:', error);
        return JSON.stringify([]);
    }
}

/**
 * Hard NMS (Non-Maximum Suppression) - Rust 로직과 동일
 */
function hardNms(faces, iouThresh) {
    // 점수 기준 내림차순 정렬
    faces.sort((a, b) => b.score - a.score);

    const picked = [];
    const suppress = new Array(faces.length).fill(false);

    for (let i = 0; i < faces.length; i++) {
        if (suppress[i]) continue;

        picked.push(faces[i]);

        for (let j = i + 1; j < faces.length; j++) {
            if (suppress[j]) continue;

            if (calculateIou(faces[i], faces[j]) > iouThresh) {
                suppress[j] = true;
            }
        }
    }

    return picked;
}

/**
 * IoU (Intersection over Union) 계산
 */
function calculateIou(a, b) {
    const interX1 = Math.max(a.x1, b.x1);
    const interY1 = Math.max(a.y1, b.y1);
    const interX2 = Math.min(a.x2, b.x2);
    const interY2 = Math.min(a.y2, b.y2);

    const interArea = Math.max(0, interX2 - interX1) * Math.max(0, interY2 - interY1);
    const areaA = (a.x2 - a.x1) * (a.y2 - a.y1);
    const areaB = (b.x2 - b.x1) * (b.y2 - b.y1);

    return interArea / (areaA + areaB - interArea);
}

/**
 * Canvas API를 사용하여 이미지에 블러 적용
 */
async function blurFacesWeb(base64ImageData, rectsJson, isCircle) {
    try {
        const rects = JSON.parse(rectsJson);

        const img = new Image();
        await new Promise((resolve, reject) => {
            img.onload = resolve;
            img.onerror = reject;
            const prefix = base64ImageData.startsWith('/9j/') ? 'data:image/jpeg;base64,' : 'data:image/png;base64,';
            img.src = prefix + base64ImageData;
        });

        const canvas = document.createElement('canvas');
        canvas.width = img.width;
        canvas.height = img.height;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0);

        for (const rect of rects) {
            applyBlurToRegion(ctx, img, rect, isCircle);
        }

        const dataUrl = canvas.toDataURL('image/png');
        const base64Result = dataUrl.split(',')[1];

        console.log('[FaceBlur] Blur applied successfully');
        return base64Result;
    } catch (error) {
        console.error('[FaceBlur] Blur error:', error);
        return base64ImageData;
    }
}

/**
 * 특정 영역에 픽셀화 블러 적용
 */
function applyBlurToRegion(ctx, img, rect, isCircle) {
    const { x, y, width, height } = rect;
    const pixelSize = Math.max(8, Math.min(width, height) / 10);

    const tempCanvas = document.createElement('canvas');
    tempCanvas.width = width;
    tempCanvas.height = height;
    const tempCtx = tempCanvas.getContext('2d');
    tempCtx.drawImage(img, x, y, width, height, 0, 0, width, height);

    const imageData = tempCtx.getImageData(0, 0, width, height);
    const data = imageData.data;

    for (let py = 0; py < height; py += pixelSize) {
        for (let px = 0; px < width; px += pixelSize) {
            if (isCircle) {
                const centerX = width / 2;
                const centerY = height / 2;
                const blockCenterX = px + pixelSize / 2;
                const blockCenterY = py + pixelSize / 2;
                const normalizedX = (blockCenterX - centerX) / (width / 2);
                const normalizedY = (blockCenterY - centerY) / (height / 2);
                if (normalizedX * normalizedX + normalizedY * normalizedY > 1) {
                    continue;
                }
            }

            let sumR = 0, sumG = 0, sumB = 0, count = 0;
            for (let by = 0; by < pixelSize && py + by < height; by++) {
                for (let bx = 0; bx < pixelSize && px + bx < width; bx++) {
                    const idx = ((py + by) * width + (px + bx)) * 4;
                    sumR += data[idx];
                    sumG += data[idx + 1];
                    sumB += data[idx + 2];
                    count++;
                }
            }

            const avgR = Math.round(sumR / count);
            const avgG = Math.round(sumG / count);
            const avgB = Math.round(sumB / count);

            for (let by = 0; by < pixelSize && py + by < height; by++) {
                for (let bx = 0; bx < pixelSize && px + bx < width; bx++) {
                    if (isCircle) {
                        const centerX = width / 2;
                        const centerY = height / 2;
                        const pixelX = px + bx;
                        const pixelY = py + by;
                        const normalizedX = (pixelX - centerX) / (width / 2);
                        const normalizedY = (pixelY - centerY) / (height / 2);
                        if (normalizedX * normalizedX + normalizedY * normalizedY > 1) {
                            continue;
                        }
                    }

                    const idx = ((py + by) * width + (px + bx)) * 4;
                    data[idx] = avgR;
                    data[idx + 1] = avgG;
                    data[idx + 2] = avgB;
                }
            }
        }
    }

    tempCtx.putImageData(imageData, 0, 0);
    ctx.drawImage(tempCanvas, 0, 0, width, height, x, y, width, height);
}

function isModelReady() {
    return session !== null;
}

// 전역으로 노출
window.FaceBlurWeb = {
    detectFacesWeb,
    blurFacesWeb,
    initFaceDetector,
    isModelReady
};

// 페이지 로드 시 모델 미리 로드
document.addEventListener('DOMContentLoaded', () => {
    console.log('[FaceBlur] Pre-loading ONNX model...');
    initFaceDetector().catch(e => console.error('[FaceBlur] Pre-load failed:', e));
});
