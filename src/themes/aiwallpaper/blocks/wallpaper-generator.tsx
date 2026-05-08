'use client';

import { cn } from '@/shared/lib/utils';
import type { Section } from '@/shared/types/blocks/landing';
import { ImageGenerator } from '@/shared/blocks/generator/image';

export function WallpaperGenerator({
  section,
  className,
}: {
  section: Section;
  className?: string;
}) {
  return (
    <section
      id={section.id}
      className={cn('py-12', section.className, className)}
    >
      <div className="container mx-auto max-w-5xl px-4">
        {section.title && (
          <h2 className="mb-8 text-center text-3xl font-bold">
            {section.title}
          </h2>
        )}
        <ImageGenerator />
      </div>
    </section>
  );
}

export default WallpaperGenerator;
