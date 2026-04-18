import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type LinkDocument = Link & Document;

@Schema({ timestamps: true })
export class Link {
  @Prop({ required: true, index: true })
  userId!: string;

  @Prop({ required: true })
  title!: string;

  @Prop({ required: true })
  url!: string;

  @Prop()
  category?: string;

  @Prop()
  description?: string;
}

export const LinkSchema = SchemaFactory.createForClass(Link);
