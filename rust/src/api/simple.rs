use flutter_rust_bridge::for_generated::anyhow;
use flutter_rust_bridge::frb;
use image::{
    DynamicImage, GenericImage, GenericImageView, ImageDecoder, ImageFormat, ImageReader,
}; // GenericImage 추가
use std::cmp::Ordering;
use std::io::Cursor;
use tract_onnx::prelude::*; // 정렬을 위해 추가

#[frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

// 좌표 정보를 담을 구조체
#[frb(dart_metadata=("freezed"))]
pub struct BlurRect {
    pub x: i32,
    pub y: i32,
    pub w: i32,
    pub h: i32,
}

fn decode_image_with_orientation(image_bytes: &[u8]) -> anyhow::Result<DynamicImage> {
    let reader = ImageReader::new(Cursor::new(image_bytes)).with_guessed_format()?;
    let mut decoder = reader.into_decoder()?;
    let orientation = decoder
        .orientation()
        .unwrap_or(image::metadata::Orientation::NoTransforms);

    let mut image = DynamicImage::from_decoder(decoder)?;
    image.apply_orientation(orientation);

    Ok(image)
}

// 이미지 바이트와 좌표(x,y,w,h)를 받아 해당 영역을 블러 처리
pub fn blur_face_area(
    image_bytes: Vec<u8>,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
) -> anyhow::Result<Vec<u8>> {
    // 1. 이미지 로드
    let mut img = decode_image_with_orientation(&image_bytes)?;
    let (img_w, img_h) = (img.width() as i32, img.height() as i32);

    // 2. 좌표 유효성 검사 (이미지 범위를 벗어나지 않도록)
    let x = x.max(0);
    let y = y.max(0);
    let w = w.min(img_w - x);
    let h = h.min(img_h - y);

    if w <= 0 || h <= 0 {
        return Ok(image_bytes); // 처리할 영역이 없으면 원본 반환
    }

    // 3. 해당 영역 크롭 (Crop)
    let sub_img = img.crop_imm(x as u32, y as u32, w as u32, h as u32);

    // 4. 블러 적용 (sigma 값 20.0은 블러 강도)
    let blurred = sub_img.blur(20.0);

    // 5. 원본 이미지 위에 블러된 이미지 덮어쓰기
    image::imageops::replace(&mut img, &blurred, x as i64, y as i64);

    // 6. 결과 이미지를 다시 바이트(PNG)로 변환
    let mut result_bytes: Vec<u8> = Vec::new();
    img.write_to(&mut Cursor::new(&mut result_bytes), ImageFormat::Png)?;

    Ok(result_bytes)
}

// // 여러 얼굴을 한 번에 블러 처리하는 함수
// pub fn blur_multiple_faces(
//     image_bytes: Vec<u8>,
//     rects: Vec<BlurRect>, // 좌표 리스트를 받음
// ) -> anyhow::Result<Vec<u8>> {
//     // 1. 이미지 로드 (한 번만 수행)
//     let mut img = load_from_memory(&image_bytes)?;
//     let (img_w, img_h) = (img.width() as i32, img.height() as i32);
//
//     // 2. 리스트를 순회하며 블러 적용
//     for rect in rects {
//         let x = rect.x.max(0);
//         let y = rect.y.max(0);
//         let w = rect.w.min(img_w - x);
//         let h = rect.h.min(img_h - y);
//
//         if w <= 0 || h <= 0 {
//             continue;
//         }
//
//         // 해당 영역 크롭 & 블러
//         let sub_img = img.crop_imm(x as u32, y as u32, w as u32, h as u32);
//         let blurred = sub_img.blur(20.0); // 블러 강도
//
//         // 원본 위에 덮어쓰기
//         image::imageops::replace(&mut img, &blurred, x as i64, y as i64);
//     }
//
//     // 3. 결과 저장 (한 번만 수행)
//     let mut result_bytes: Vec<u8> = Vec::new();
//     img.write_to(&mut Cursor::new(&mut result_bytes), ImageFormat::Png)?;
//
//     Ok(result_bytes)
// }

// ==========================================
// Desktop 얼굴 탐지 (RFB-640 모델 전용)
// ==========================================
pub fn detect_faces_desktop(
    image_bytes: Vec<u8>,
    model_bytes: Vec<u8>,
) -> anyhow::Result<Vec<BlurRect>> {
    let img = decode_image_with_orientation(&image_bytes)?;
    let (orig_w, orig_h) = img.dimensions();

    // 1. 모델 입력 크기 변경 (320 -> 640, 240 -> 480)
    let model = tract_onnx::onnx()
        .model_for_read(&mut Cursor::new(model_bytes))?
        .with_input_fact(0, f32::fact([1, 3, 480, 640]).into())? // 🛠️ 수정됨
        .into_optimized()?
        .into_runnable()?;

    // 2. 이미지 리사이징 변경 (640x480)
    let resized = img.resize_exact(640, 480, image::imageops::FilterType::Triangle); // 🛠️ 수정됨

    let tensor: Tensor = tract_ndarray::Array4::from_shape_fn((1, 3, 480, 640), |(_, c, y, x)| {
        // 🛠️ 수정됨
        let pixel = resized.get_pixel(x as u32, y as u32);
        let val = pixel[c as usize] as f32;
        (val - 127.0) / 128.0
    })
    .into();

    let result = model.run(tvec!(tensor.into()))?;
    let confidences = result[0].to_array_view::<f32>()?;
    let boxes = result[1].to_array_view::<f32>()?;

    // 3. 앵커(Priors) 생성 함수 호출
    let priors = generate_priors_640(); // 🛠️ 640 전용 함수로 변경
    let mut detected_faces = Vec::new();

    // 🔍 팁: 놓치는 얼굴이 있다면 이 점수를 0.6이나 0.5로 낮춰보세요.
    let score_threshold = 0.6;
    let iou_threshold = 0.3;
    let center_variance = 0.1;
    let size_variance = 0.2;

    for i in 0..priors.len() {
        let score = confidences[[0, i, 1]];
        if score > score_threshold {
            let prior = &priors[i];

            let loc_cx = boxes[[0, i, 0]];
            let loc_cy = boxes[[0, i, 1]];
            let loc_w = boxes[[0, i, 2]];
            let loc_h = boxes[[0, i, 3]];

            let cx = prior.cx + loc_cx * center_variance * prior.w;
            let cy = prior.cy + loc_cy * center_variance * prior.h;
            let w = prior.w * (loc_w * size_variance).exp();
            let h = prior.h * (loc_h * size_variance).exp();

            let x = (cx - w / 2.0) * orig_w as f32;
            let y = (cy - h / 2.0) * orig_h as f32;
            let real_w = w * orig_w as f32;
            let real_h = h * orig_h as f32;

            detected_faces.push(Face {
                x1: x,
                y1: y,
                x2: x + real_w,
                y2: y + real_h,
                score,
            });
        }
    }

    let final_faces = hard_nms(detected_faces, iou_threshold);

    let results = final_faces
        .into_iter()
        .map(|f| BlurRect {
            x: f.x1 as i32,
            y: f.y1 as i32,
            w: (f.x2 - f.x1) as i32,
            h: (f.y2 - f.y1) as i32,
        })
        .collect();

    Ok(results)
}

// --- Helper Functions ---

struct Face {
    x1: f32,
    y1: f32,
    x2: f32,
    y2: f32,
    score: f32,
}

struct Prior {
    cx: f32,
    cy: f32,
    w: f32,
    h: f32,
}

// 🛠️ [중요] 640x480 해상도에 맞게 앵커 박스 생성 로직 수정
fn generate_priors_640() -> Vec<Prior> {
    let input_w = 640.0;
    let input_h = 480.0;

    // Feature Map 크기도 2배로 늘어남
    // 320일때: [[40, 30], [20, 15], [10, 8], [5, 4]]
    // 640일때: 아래와 같음
    let feature_maps = [[80, 60], [40, 30], [20, 15], [10, 8]];

    let min_sizes: &[&[f32]] = &[
        &[10.0, 16.0, 24.0],
        &[32.0, 48.0],
        &[64.0, 96.0],
        &[128.0, 192.0, 256.0],
    ];

    let steps = [8.0, 16.0, 32.0, 64.0];

    let mut priors = Vec::new();

    for (k, map_size) in feature_maps.iter().enumerate() {
        let min_size = min_sizes[k];
        let step = steps[k];

        for i in 0..map_size[1] {
            for j in 0..map_size[0] {
                let cx = (j as f32 + 0.5) * step / input_w;
                let cy = (i as f32 + 0.5) * step / input_h;

                for size in min_size {
                    priors.push(Prior {
                        cx,
                        cy,
                        w: size / input_w,
                        h: size / input_h,
                    });
                }
            }
        }
    }
    priors
}

fn hard_nms(mut faces: Vec<Face>, iou_thresh: f32) -> Vec<Face> {
    faces.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap_or(Ordering::Equal));
    let mut picked = Vec::new();
    let mut suppress = vec![false; faces.len()];

    for i in 0..faces.len() {
        if suppress[i] {
            continue;
        }
        picked.push(i);
        for j in (i + 1)..faces.len() {
            if suppress[j] {
                continue;
            }
            if calculate_iou(&faces[i], &faces[j]) > iou_thresh {
                suppress[j] = true;
            }
        }
    }

    picked
        .into_iter()
        .map(|idx| {
            let f = &faces[idx];
            Face {
                x1: f.x1,
                y1: f.y1,
                x2: f.x2,
                y2: f.y2,
                score: f.score,
            }
        })
        .collect()
}

fn calculate_iou(a: &Face, b: &Face) -> f32 {
    let inter_x1 = a.x1.max(b.x1);
    let inter_y1 = a.y1.max(b.y1);
    let inter_x2 = a.x2.min(b.x2);
    let inter_y2 = a.y2.min(b.y2);

    let inter_area = (inter_x2 - inter_x1).max(0.0) * (inter_y2 - inter_y1).max(0.0);
    let area_a = (a.x2 - a.x1) * (a.y2 - a.y1);
    let area_b = (b.x2 - b.x1) * (b.y2 - b.y1);

    inter_area / (area_a + area_b - inter_area)
}

// ==========================================
// 2. 블러 처리 (원형/사각형 선택 기능 추가)
// ==========================================
pub fn blur_multiple_faces(
    image_bytes: Vec<u8>,
    rects: Vec<BlurRect>,
    is_circle: bool, // ✨ 모양 선택 파라미터 추가
) -> anyhow::Result<Vec<u8>> {
    let mut img = decode_image_with_orientation(&image_bytes)?;
    let (img_w, img_h) = (img.width() as i32, img.height() as i32);

    for rect in rects {
        let x = rect.x.max(0);
        let y = rect.y.max(0);
        let w = rect.w.min(img_w - x);
        let h = rect.h.min(img_h - y);

        if w <= 0 || h <= 0 {
            continue;
        }

        // 1. 해당 영역 잘라내서 블러 처리
        let sub_img = img.crop_imm(x as u32, y as u32, w as u32, h as u32);
        let blurred = sub_img.blur(20.0);

        if is_circle {
            // ✨ [원형/타원 블러 로직]
            // 타원 방정식: ((x-cx)/a)^2 + ((y-cy)/b)^2 <= 1
            let center_x = w as f32 / 2.0;
            let center_y = h as f32 / 2.0;
            let radius_x = w as f32 / 2.0;
            let radius_y = h as f32 / 2.0;

            for dy in 0..h {
                for dx in 0..w {
                    // 현재 픽셀이 타원 안에 있는지 확인
                    let norm_x = (dx as f32 - center_x) / radius_x;
                    let norm_y = (dy as f32 - center_y) / radius_y;

                    if (norm_x * norm_x + norm_y * norm_y) <= 1.0 {
                        // 타원 내부라면 -> 블러된 픽셀로 교체
                        let pixel = blurred.get_pixel(dx as u32, dy as u32);
                        img.put_pixel((x + dx) as u32, (y + dy) as u32, pixel);
                    }
                    // 타원 밖이라면 -> 원본 유지 (아무것도 안 함)
                }
            }
        } else {
            // ✨ [사각형 블러 로직] - 기존과 동일하게 통째로 덮어쓰기
            image::imageops::replace(&mut img, &blurred, x as i64, y as i64);
        }
    }

    let mut result_bytes: Vec<u8> = Vec::new();
    img.write_to(&mut Cursor::new(&mut result_bytes), ImageFormat::Png)?;
    Ok(result_bytes)
}
